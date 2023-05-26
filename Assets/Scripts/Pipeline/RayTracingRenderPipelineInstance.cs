using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Experimental.Rendering.RenderGraphModule;

public class RayTracingRenderPipelineInstance : RenderPipeline
{
    private RayTracingRenderPipelineAsset renderPipelineAsset;

    private RayTracingAccelerationStructure rtas = null;

    private RenderGraph renderGraph = null;

    private RTHandleSystem rtHandleSystem = null;

    private int convergenceStep = 0;

    class RayTracingRenderPassData
    {
        public TextureHandle outputTexture;
    };

    public RayTracingRenderPipelineInstance(RayTracingRenderPipelineAsset asset)
    {
        renderPipelineAsset = asset;

        var settings = new RayTracingAccelerationStructure.Settings()
        {
            rayTracingModeMask = RayTracingAccelerationStructure.RayTracingModeMask.Everything,
            managementMode = RayTracingAccelerationStructure.ManagementMode.Manual,
            layerMask = 255
        };

        rtas = new RayTracingAccelerationStructure(settings);

        renderGraph = new RenderGraph("Ray Tracing Render Graph");

        rtHandleSystem = new RTHandleSystem();
    }

    protected override void Dispose(bool disposing)
    {
        if (rtas != null)
        {
            rtas.Release();
            rtas = null;
        }

        renderGraph.Cleanup();
        renderGraph = null;

        rtHandleSystem.Dispose();
    }

    private bool ValidateRayTracing()
    {
        if (!SystemInfo.supportsRayTracing)
        {
            Debug.Log("Ray Tracing API is not supported!");
            return false;
        }

        if (rtas == null)
        {
            Debug.Log("Ray Tracing Acceleration Structure is null!");
            return false;
        }

        return true;
    }

    private void CullInstance()
    {
        var instanceCullingTest = new RayTracingInstanceCullingTest()
        {
            allowOpaqueMaterials = true,
            allowTransparentMaterials = false,
            allowAlphaTestedMaterials = true,
            layerMask = -1,
            shadowCastingModeMask = (1 << (int)ShadowCastingMode.Off)
            | (1 << (int)ShadowCastingMode.On)
            | (1 << (int)ShadowCastingMode.TwoSided),
            instanceMask = 1 << 0,
        };

        var instanceCullingTests = new List<RayTracingInstanceCullingTest>() { instanceCullingTest };

        var cullingConfig = new RayTracingInstanceCullingConfig()
        {
            flags = RayTracingInstanceCullingFlags.None,
            subMeshFlagsConfig = new RayTracingSubMeshFlagsConfig()
            {
                opaqueMaterials = RayTracingSubMeshFlags.Enabled | RayTracingSubMeshFlags.ClosestHitOnly,
                transparentMaterials = RayTracingSubMeshFlags.Disabled,
                alphaTestedMaterials = RayTracingSubMeshFlags.Enabled,
            },
            instanceTests = instanceCullingTests.ToArray(),
        };

        rtas.ClearInstances();
        rtas.CullInstances(ref cullingConfig);
    }

    private Light FindPointLight()
    {
        Light pointLight = Object.FindFirstObjectByType<Light>();

        if (pointLight == null || pointLight.type != LightType.Point) return null;

        return pointLight;
    }

    protected override void Render(ScriptableRenderContext context, Camera[] cameras)
    {
        if (!ValidateRayTracing())
        {
            CommandBuffer cmd = new CommandBuffer();
            cmd.ClearRenderTarget(true, true, Color.magenta);
            context.ExecuteCommandBuffer(cmd);
            context.Submit();
            cmd.Release();
            return;
        }

        CullInstance();

        foreach (Camera camera in cameras)
        {
            if (!camera.TryGetComponent<AdditionalCameraData>(out var additionalData))
            {
                additionalData = camera.gameObject.AddComponent<AdditionalCameraData>();
                additionalData.hideFlags = HideFlags.HideAndDontSave;
            }

            if (additionalData.UpdateCameraResources()) convergenceStep = 0;

            CommandBuffer cmd = new CommandBuffer();

            if ((camera.cameraType & renderPipelineAsset.activeCameraType) > 0)
            {
                context.SetupCameraProperties(camera);

                var renderGraphParams = new RenderGraphParameters()
                {
                    scriptableRenderContext = context,
                    commandBuffer = cmd,
                    currentFrameIndex = additionalData.frameIndex
                };

                RTHandle outputRTHandle = rtHandleSystem.Alloc(additionalData.rayTracingOutput, "g_Output");

                switch(renderPipelineAsset.rayTracingStyle)
                {
                    case RayTracingStyle.PATH_TRACING:
                        if(DoPathTracing(camera, outputRTHandle, renderGraphParams, additionalData))
                        {
                            cmd.Blit(additionalData.rayTracingOutput, camera.activeTexture);
                        }
                        else
                        {
                            cmd.ClearRenderTarget(false, true, Color.black);
                            Debug.Log("Error occurred when Path Tracing!");
                        }
                        break;
                }

                outputRTHandle.Release();
            }
            else
            {
                cmd.ClearRenderTarget(false, true, Color.black);
            }

            context.ExecuteCommandBuffer(cmd);

            cmd.Release();

            context.Submit();

            renderGraph.EndFrame();

            additionalData.UpdateCameraData();
        }
    }

    private bool DoPathTracing(Camera camera, RTHandle outputRTHandle, RenderGraphParameters renderGraphParams, AdditionalCameraData additionalData)
    {

        if (renderPipelineAsset.pathTracingShader == null)
        {
            Debug.Log("Ray Tracing Shader is null!");
            return false;
        }

        using (renderGraph.RecordAndExecute(renderGraphParams))
        {
            TextureHandle output = renderGraph.ImportTexture(outputRTHandle);

            RenderGraphBuilder builder = renderGraph.AddRenderPass<RayTracingRenderPassData>("Path Tracing Pass", out var passData);

            passData.outputTexture = builder.WriteTexture(output);

            TextureDesc desc = new TextureDesc()
            {
                dimension = TextureDimension.Tex2D,
                width = camera.pixelWidth,
                height = camera.pixelHeight,
                depthBufferBits = 0,
                colorFormat = GraphicsFormat.R16G16B16A16_SFloat,
                slices = 1,
                msaaSamples = MSAASamples.None,
                enableRandomWrite = true,
            };
            TextureHandle debugTexture = builder.CreateTransientTexture(desc);

            builder.SetRenderFunc((RayTracingRenderPassData data, RenderGraphContext ctx) =>
            {
                ctx.cmd.BuildRayTracingAccelerationStructure(rtas);

                ctx.cmd.SetRayTracingShaderPass(renderPipelineAsset.pathTracingShader, "PathTracing");

                float zoom = Mathf.Tan(Mathf.Deg2Rad * camera.fieldOfView * 0.5f);
                float aspectRatio = camera.pixelWidth / (float)camera.pixelHeight;

                ctx.cmd.SetGlobalInt(Shader.PropertyToID("g_BounceCountOpaque"), (int)renderPipelineAsset.bounceCountOpaque);
                ctx.cmd.SetGlobalInt(Shader.PropertyToID("g_BounceCountTransparent"), (int)renderPipelineAsset.bounceCountTransparent);

                ctx.cmd.SetRayTracingAccelerationStructure(renderPipelineAsset.pathTracingShader, Shader.PropertyToID("g_AccelStruct"), rtas);
                ctx.cmd.SetRayTracingFloatParam(renderPipelineAsset.pathTracingShader, Shader.PropertyToID("g_Zoom"), zoom);
                ctx.cmd.SetRayTracingFloatParam(renderPipelineAsset.pathTracingShader, Shader.PropertyToID("g_AspectRatio"), aspectRatio);
                ctx.cmd.SetRayTracingIntParam(renderPipelineAsset.pathTracingShader, Shader.PropertyToID("g_ConvergenceStep"), convergenceStep);
                ctx.cmd.SetRayTracingIntParam(renderPipelineAsset.pathTracingShader, Shader.PropertyToID("g_FrameIndex"), additionalData.frameIndex);
                ctx.cmd.SetRayTracingTextureParam(renderPipelineAsset.pathTracingShader, Shader.PropertyToID("g_EnvTex"), renderPipelineAsset.envTexture);
                ctx.cmd.SetRayTracingTextureParam(renderPipelineAsset.pathTracingShader, Shader.PropertyToID("g_DebugTex"), debugTexture);
                ctx.cmd.SetRayTracingTextureParam(renderPipelineAsset.pathTracingShader, Shader.PropertyToID("g_Output"), passData.outputTexture);

                ctx.cmd.DispatchRays(renderPipelineAsset.pathTracingShader, "PathTracingRayGenShader", (uint)camera.pixelWidth, (uint)camera.pixelHeight, 1, camera);

                convergenceStep++;
            });
        }

        return true;
    }
}