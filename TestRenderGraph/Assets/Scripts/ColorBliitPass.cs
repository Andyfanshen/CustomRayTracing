using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;

public class ColorBlitPass : ScriptableRenderPass
{
    class PassData
    {
        public Material BlitMaterial { get; set; }
        public TextureHandle SourceTexture { get; set; }

        internal TextureHandle destHalf;
        internal TextureHandle destQuarter;
    }

    private Material m_InvertColorMaterial;
    private Material m_BlitMaterial;
    private ProfilingSampler m_ProfilingSampler = new ProfilingSampler("After Opaques");

    public ColorBlitPass(Material invertColorMaterial, Material blitMaterial, RenderPassEvent rpEvent)
    {
        m_InvertColorMaterial = invertColorMaterial;
        m_BlitMaterial = blitMaterial;
        renderPassEvent = rpEvent;
    }

    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
        UniversalCameraData cameraData = frameData.Get<UniversalCameraData>();

        TextureHandle sourceTexture = resourceData.activeColorTexture;

        // Temporary destination texture for blitting.
        RenderTextureDescriptor descriptor = cameraData.cameraTargetDescriptor;

        // No need the depth buffer.
        descriptor.depthBufferBits = 0;

        TextureHandle destinationTexture = UniversalRenderer.CreateRenderGraphTexture(renderGraph, descriptor, "_TempRT", true);

        // Blit from source color buffer to the temporary RT.
        using (var builder = renderGraph.AddRasterRenderPass<PassData>("After Opaque Post-processing pass", out var passData, m_ProfilingSampler))
        {
            passData.BlitMaterial = m_InvertColorMaterial;

            // Read the sourceTexture as pass input.
            builder.UseTexture(sourceTexture, AccessFlags.Read);
            passData.SourceTexture = sourceTexture;

            // Bind the temporary texture as a framebuffer color attachment at index 0.
            builder.SetRenderAttachment(destinationTexture, 0, AccessFlags.Write);

            builder.SetRenderFunc((PassData data, RasterGraphContext rgContext) => ExecutePass(data, rgContext));
        }

        // Blit from destination to source.
        using (var builder = renderGraph.AddRasterRenderPass<PassData>("Color Blit Resolve", out var passData, m_ProfilingSampler))
        {
            passData.BlitMaterial = m_BlitMaterial;

            builder.UseTexture(destinationTexture, AccessFlags.Read);
            passData.SourceTexture = destinationTexture;

            builder.SetRenderAttachment(sourceTexture, 0, AccessFlags.Write);

            builder.SetRenderFunc((PassData data, RasterGraphContext rgContext) => ExecutePass(data, rgContext));
        }

        // Downsample & upsample unsafe pass
        using (var builder = renderGraph.AddUnsafePass<PassData>("Unsafe Pass", out var passData))
        {
            descriptor.msaaSamples = 1;
            TextureHandle destination = UniversalRenderer.CreateRenderGraphTexture(renderGraph, descriptor, "UnsafeTexture", false);

            descriptor.width /= 2;
            descriptor.height /= 2;
            TextureHandle destinationHalf = UniversalRenderer.CreateRenderGraphTexture(renderGraph, descriptor, "UnsafeTexture2", false);
            descriptor.width /= 2;
            descriptor.height /= 2;
            TextureHandle destinationQuarter = UniversalRenderer.CreateRenderGraphTexture(renderGraph, descriptor, "UnsafeTexture3", false);

            passData.SourceTexture = sourceTexture;
            passData.destHalf = destinationHalf;
            passData.destQuarter = destinationQuarter;

            builder.UseTexture(passData.SourceTexture);
            builder.UseTexture(passData.destHalf, AccessFlags.Write);
            builder.UseTexture(passData.destQuarter, AccessFlags.Write);
            builder.AllowPassCulling(false);
            builder.SetRenderFunc((PassData data, UnsafeGraphContext rgContext) => ExecuteDownsamplePass(data, rgContext));
        }
    }

    static void ExecutePass(PassData data, RasterGraphContext rgContext)
    {
        Blitter.BlitTexture(rgContext.cmd, data.SourceTexture, new Vector4(1, 1, 0, 0), data.BlitMaterial, 0);
    }

    static void ExecuteDownsamplePass(PassData data, UnsafeGraphContext rgContext)
    {
        CommandBuffer unsafeCmd = CommandBufferHelpers.GetNativeCommandBuffer(rgContext.cmd);

        // Downscale x2

        unsafeCmd.SetRenderTarget(data.destHalf);
        Blitter.BlitTexture(unsafeCmd, data.SourceTexture, new Vector4(1, 1, 0, 0), 0, false);

        unsafeCmd.SetRenderTarget(data.destQuarter);
        Blitter.BlitTexture(unsafeCmd, data.destHalf, new Vector4(1, 1, 0, 0), 0, false);

        // Upscale x2

        unsafeCmd.SetRenderTarget(data.destHalf);
        Blitter.BlitTexture(unsafeCmd, data.destQuarter, new Vector4(1, 1, 0, 0), 0, false);

        unsafeCmd.SetRenderTarget(data.SourceTexture);
        Blitter.BlitTexture(unsafeCmd, data.destHalf, new Vector4(1, 1, 0, 0), 0, false);
    }
}
