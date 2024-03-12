using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;
using System.Collections.Generic;
using UnityEngine.Experimental.Rendering;
using Unity.Mathematics;
using System.Linq;
using Unity.VisualScripting;

namespace UnityEngine.Rendering.Universal
{

    public class PathTracingPass : ScriptableRenderPass
    {
        sealed class PathTracingPersistenData : CameraHistoryItem
        {
            private int m_AccumulationTextureId;
            private static readonly string m_AccumulationName = "PathTracingTex";
            private RenderTextureDescriptor m_Descriptor;
            private Hash128 m_DescKey;

            private int m_ConvergenceStep;
            public int ConvergenceStep
            {
                get { return m_ConvergenceStep; }
            }

            private Matrix4x4 m_prevCameraMatrix;

            private const int MAX_BUFFERS_RESTIR = 2;
            private ComputeBuffer[] m_restirBuffers;

            public override void OnCreate(BufferedRTHandleSystem owner, uint typeId)
            {
                base.OnCreate(owner, typeId);
                m_AccumulationTextureId = MakeId(typeId);
                m_ConvergenceStep = 0;
                m_prevCameraMatrix = Matrix4x4.identity;
                m_restirBuffers = null;
            }

            public void ReCreateReSTIRBuffer(int width, int height)
            {
                if (m_restirBuffers != null)
                {
                    for (int i = 0; i < MAX_BUFFERS_RESTIR; i++)
                    {
                        m_restirBuffers[i].Release();
                        m_restirBuffers[i].Dispose();
                    }
                }

                // Alloc ReSTIR Buffer
                m_restirBuffers = new ComputeBuffer[MAX_BUFFERS_RESTIR];
                for (int i = 0; i < MAX_BUFFERS_RESTIR; i++)
                {
                    m_restirBuffers[i] = new ComputeBuffer(width * height, sizeof(float) * 15, ComputeBufferType.Structured);
                }
            }

            public void CheckAndAllocReSTIRBuffer(int width, int height)
            {
                if (m_restirBuffers == null)
                {
                    // Alloc ReSTIR Buffer
                    m_restirBuffers = new ComputeBuffer[MAX_BUFFERS_RESTIR];
                    for (int i = 0; i < MAX_BUFFERS_RESTIR; i++)
                    {
                        m_restirBuffers[i] = new ComputeBuffer(width * height, sizeof(float) * 18, ComputeBufferType.Structured);
                    }
                }
            }

            public override void Reset()
            {
                ReleaseHistoryFrameRT(m_AccumulationTextureId);
                m_Descriptor.width = 0;
                m_Descriptor.height = 0;
                m_Descriptor.graphicsFormat = GraphicsFormat.None;
                m_DescKey = Hash128.Compute(0);
                m_ConvergenceStep = 0;
                m_prevCameraMatrix = Matrix4x4.identity;
            }

            public RTHandle GetAccumulationTexture()
            {
                return GetCurrentFrameRT(m_AccumulationTextureId);
            }

            public ComputeBuffer GetCurrentRestirBuffer(int gid)
            {
                return m_restirBuffers[gid];
            }

            private bool IsValid()
            {
                return GetAccumulationTexture() != null;
            }

            private bool IsDirty(ref RenderTextureDescriptor desc)
            {
                return m_DescKey != Hash128.Compute(ref desc);
            }

            private void Alloc(ref RenderTextureDescriptor desc)
            {
                AllocHistoryFrameRT(m_AccumulationTextureId, 1, ref desc, m_AccumulationName);

                m_Descriptor = desc;
                m_DescKey = Hash128.Compute(ref desc);
            }

            internal void Update(ref RenderTextureDescriptor cameraDesc, bool accumulation, Matrix4x4 cameraMatrix)
            {
                // Accumulation Update
                m_ConvergenceStep = (m_prevCameraMatrix.Equals(cameraMatrix) && accumulation) ? m_ConvergenceStep + 1 : 0;
                m_prevCameraMatrix = cameraMatrix;

                // Accumulation RenderTexture Update
                if (cameraDesc.width > 0 && cameraDesc.height > 0 && cameraDesc.graphicsFormat != GraphicsFormat.None)
                {
                    var accDesc = cameraDesc;
                    accDesc.width = cameraDesc.width;
                    accDesc.height = cameraDesc.height;
                    accDesc.msaaSamples = 1;
                    accDesc.mipCount = 0;
                    accDesc.graphicsFormat = GraphicsFormat.R32G32B32A32_SFloat;
                    accDesc.sRGB = false;
                    accDesc.depthBufferBits = 0;
                    accDesc.dimension = cameraDesc.dimension;
                    accDesc.memoryless = cameraDesc.memoryless;
                    accDesc.useMipMap = false;
                    accDesc.autoGenerateMips = false;
                    accDesc.enableRandomWrite = true;
                    accDesc.bindMS = false;
                    accDesc.useDynamicScale = false;

                    if (IsDirty(ref accDesc))
                    {
                        Reset();
                    }

                    if (!IsValid())
                    {
                        Alloc(ref accDesc);
                    }
                }                
            }
        }

        class PathTracingPassData
        {
            public RayTracingShader shader;
            public Material blitMaterial;

            public int width, height;
            public RayTracingAccelerationStructure accelerationStructure;
            public Texture envTexture;
            public float zoom;
            public float aspectRatio;
            public int convergenceStep;
            public int frameIndex;
            public int frameCount;
            public int bounceCount;
            public int maxSamples;
            public Vector4 directionalLight;

            public bool restir;
            public ComputeBuffer restirBuffer;
            public bool clearBuffer;

            public TextureHandle depthTexture;
            public TextureHandle albedoBufferTexture;
            public TextureHandle specularBufferTexture;
            public TextureHandle normalBufferTexture;
            public TextureHandle output;
        }

        class BlitPassData
        {
            public Material blitMaterial;
            public TextureHandle sourceTexture;
            public float convergenceRatio;
        }

        class DebugBlitData
        {
            public Material blitMaterial;
            public TextureHandle sourceTexture;
        }

        internal RayTracingResources rayTracingResources { get; private set; }
        private PathTracing m_PathTracing;
        private ProfilingSampler m_ProfilingSampler = new ProfilingSampler("Path Tracing");
        private RayTracingAccelerationStructure m_AccelerationStructure;
        private RayTracingInstanceCullingConfig m_InstanceCullingConfig;

        public PathTracingPass(RenderPassEvent rpEvent)
        {
            rayTracingResources = GraphicsSettings.GetRenderPipelineSettings<RayTracingResources>();

            var rtasSettings = new RayTracingAccelerationStructure.Settings()
            {
                rayTracingModeMask = RayTracingAccelerationStructure.RayTracingModeMask.Everything,
                managementMode = RayTracingAccelerationStructure.ManagementMode.Manual,
                layerMask = -1
            };
            m_AccelerationStructure = new RayTracingAccelerationStructure(rtasSettings);

            m_InstanceCullingConfig = RTASInstanceCullingConfig();

            renderPassEvent = rpEvent;
        }

        private RayTracingInstanceCullingConfig RTASInstanceCullingConfig()
        {
            // Configure instance tests. There can be one instance test for each ray tracing effect for example.
            // The purpose of instance tests is to use different settings (layer, material types) per ray tracing effect.
            // Use InstanceInclusionMask argument of TraceRay HLSL function to mask different instance types.

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

            return new RayTracingInstanceCullingConfig()
            {
                flags = RayTracingInstanceCullingFlags.None,
                subMeshFlagsConfig = new RayTracingSubMeshFlagsConfig()
                {
                    // Disable anyhit shaders for opaque geometries for best ray tracing performance.
                    opaqueMaterials = RayTracingSubMeshFlags.Enabled | RayTracingSubMeshFlags.ClosestHitOnly,
                    // Disable transparent geometries.
                    transparentMaterials = RayTracingSubMeshFlags.Disabled,
                    // Enable anyhit shaders for alpha-tested / cutout geometries.
                    alphaTestedMaterials = RayTracingSubMeshFlags.Enabled,
                },
                instanceTests = instanceCullingTests.ToArray(),
            };
        }

        private void UpdateRTAS()
        {
            m_AccelerationStructure.ClearInstances();
            m_AccelerationStructure.CullInstances(ref m_InstanceCullingConfig);
            m_AccelerationStructure.Build();
        }

        private bool IsValid()
        {
            if (!SystemInfo.supportsRayTracing) return false;
            if (rayTracingResources == null) return false;
            if (m_PathTracing == null) return false;
            if (m_AccelerationStructure == null) return false;

            return true;
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            var stack = VolumeManager.instance.stack;
            m_PathTracing = stack.GetComponent<PathTracing>();

            if (!IsValid())
            {
                Debug.Log("Path tracing is invalid!");
                return;
            }

            UpdateRTAS();

            UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
            UniversalCameraData cameraData = frameData.Get<UniversalCameraData>();
            UniversalCameraHistory history = cameraData.historyManager;

            //Debug Pass
            if (m_PathTracing.debugMode.value)
            {
                //_GBuffer0 is Albedo
                //_GBuffer1 is SpecularMetallic
                //_GBuffer2 is NormalSmoothness
                //_GBuffer3 is Lighting
                //_GBuffer4 is Depth

                //Others in resourceData: cameraDepthTexture, motionVectorColor...

                // Debug Enter Point
                TextureHandle sourceTexture = resourceData.cameraDepthTexture;

                TextureHandle destination = resourceData.activeColorTexture;

                using (var builder = renderGraph.AddRasterRenderPass<DebugBlitData>("Debug Blit Pass", out var passData, m_ProfilingSampler))
                {
                    passData.blitMaterial = rayTracingResources.DebugBlitMaterial;
                    builder.SetRenderAttachment(destination, 0);
                    passData.sourceTexture = sourceTexture;
                    builder.UseTexture(sourceTexture);

                    builder.SetRenderFunc((DebugBlitData data, RasterGraphContext rgContext) =>
                    {
                        Blitter.BlitTexture(rgContext.cmd, data.sourceTexture, new Vector4(1, 1, 0, 0), data.blitMaterial, 0);
                    });
                }

                return;
            }
            //-Debug Pass

            if (history == null)
            {
                // Camera has no history data.
                return;
            }
            else
            {// Camera has history data, do accumulation.
                history.RequestAccess<PathTracingPersistenData>();
                var accumulationHistory = history.GetHistoryForWrite<PathTracingPersistenData>();
                if (accumulationHistory != null)
                {
                    accumulationHistory.Update(ref cameraData.cameraTargetDescriptor, m_PathTracing.accumulation.value, cameraData.camera.cameraToWorldMatrix);
                    accumulationHistory.CheckAndAllocReSTIRBuffer(cameraData.camera.pixelWidth, cameraData.camera.pixelHeight);

                    if (accumulationHistory.GetAccumulationTexture() != null)
                    {
                        TextureHandle destination = resourceData.activeColorTexture;
                        TextureHandle frameTexture = renderGraph.ImportTexture(accumulationHistory.GetAccumulationTexture());

                        TextureHandle depthTexture = resourceData.cameraDepthTexture;
                        TextureHandle albedoBufferTexture = resourceData.gBuffer[0];
                        TextureHandle specularBufferTexture = resourceData.gBuffer[1];
                        TextureHandle normalBufferTexture = resourceData.gBuffer[2];

                        int convergenceStep = 0;

                        // Yet not achieve the max samples
                        if (accumulationHistory.ConvergenceStep < m_PathTracing.maximumSamples.value)
                        {
                            convergenceStep = m_PathTracing.accumulation.value ? accumulationHistory.ConvergenceStep : 0;

                            Light sun = Object.FindObjectsByType<Light>(FindObjectsSortMode.None).Where(x => x.type == LightType.Directional).FirstOrDefault();
                            //Vector4 directionalLight = new Vector4();
                            //if(sun != null)
                            //{
                            //    Vector3 direction = -sun.transform.forward;
                            //    directionalLight = new Vector4(direction.x, direction.y, direction.z, sun.intensity * 10);
                            //}

                            using (var builder = renderGraph.AddRenderPass<PathTracingPassData>("Path Tracing pass", out var passData, m_ProfilingSampler))
                            {
                                // Input buffers
                                passData.shader = rayTracingResources.PathTracingRT;
                                passData.envTexture = m_PathTracing.envTexture.value;
                                passData.depthTexture = builder.ReadTexture(depthTexture);
                                passData.albedoBufferTexture = builder.ReadTexture(albedoBufferTexture);
                                passData.specularBufferTexture = builder.ReadTexture(specularBufferTexture);
                                passData.normalBufferTexture = builder.ReadTexture(normalBufferTexture);
                                passData.restir = m_PathTracing.restir.value;
                                passData.restirBuffer = accumulationHistory.GetCurrentRestirBuffer(0);
                                passData.clearBuffer = m_PathTracing.clearRestirBuffer.value;
                                passData.bounceCount = m_PathTracing.bounceCount.value;
                                passData.maxSamples = m_PathTracing.maximumSamples.value;
                                passData.frameCount = Time.frameCount;
                                passData.blitMaterial = rayTracingResources.BlitMaterial;
                                passData.width = cameraData.camera.pixelWidth;
                                passData.height = cameraData.camera.pixelHeight;
                                passData.aspectRatio = cameraData.camera.aspect;
                                passData.zoom = Mathf.Tan(Mathf.Deg2Rad * cameraData.camera.fieldOfView * 0.5f);
                                passData.accelerationStructure = m_AccelerationStructure;
                                passData.convergenceStep = convergenceStep;
                                //passData.directionalLight = directionalLight;

                                // Temporary buffers
                                //passData.depthTexture = builder.CreateTransientTexture(new TextureDesc(Vector2.one, true, true)
                                //{
                                //    colorFormat = GraphicsFormat.R32_SFloat,
                                //    enableRandomWrite = true,
                                //    name = "DepthBuffer"
                                //});

                                // Output buffers
                                passData.output = builder.ReadWriteTexture(frameTexture);

                                builder.SetRenderFunc((PathTracingPassData data, RenderGraphContext ctx) =>
                                {
                                    ctx.cmd.SetRayTracingShaderPass(data.shader, "PathTracing");
                                    ctx.cmd.SetRayTracingIntParam(data.shader, Shader.PropertyToID("g_BounceCountOpaque"), data.bounceCount);
                                    ctx.cmd.SetRayTracingIntParam(data.shader, Shader.PropertyToID("g_BounceCountTransparent"), data.bounceCount);
                                    ctx.cmd.SetRayTracingAccelerationStructure(data.shader, Shader.PropertyToID("g_AccelStruct"), data.accelerationStructure);
                                    ctx.cmd.SetRayTracingFloatParam(data.shader, Shader.PropertyToID("g_Zoom"), data.zoom);
                                    ctx.cmd.SetRayTracingFloatParam(data.shader, Shader.PropertyToID("g_AspectRatio"), data.aspectRatio);
                                    ctx.cmd.SetRayTracingIntParam(data.shader, Shader.PropertyToID("g_ConvergenceStep"), data.convergenceStep);
                                    ctx.cmd.SetRayTracingIntParam(data.shader, Shader.PropertyToID("g_FrameIndex"), data.frameCount);
                                    ctx.cmd.SetRayTracingIntParam(data.shader, Shader.PropertyToID("g_MaxSamples"), data.maxSamples);
                                    //ctx.cmd.SetRayTracingVectorParam(data.shader, Shader.PropertyToID("g_DirectionalLight"), data.directionalLight);
                                    ctx.cmd.SetRayTracingTextureParam(data.shader, Shader.PropertyToID("_DepthTex"), data.depthTexture);
                                    ctx.cmd.SetRayTracingTextureParam(data.shader, Shader.PropertyToID("_AlbedoBufferTex"), data.albedoBufferTexture);
                                    ctx.cmd.SetRayTracingTextureParam(data.shader, Shader.PropertyToID("_SpecularBufferTex"), data.specularBufferTexture);
                                    ctx.cmd.SetRayTracingTextureParam(data.shader, Shader.PropertyToID("_NormalBufferTex"), data.normalBufferTexture);
                                    ctx.cmd.SetRayTracingIntParam(data.shader, Shader.PropertyToID("g_ReSTIR"), passData.restir ? 1 : 0);
                                    ctx.cmd.SetRayTracingIntParam(data.shader, Shader.PropertyToID("g_ClearBuffer"), passData.clearBuffer ? 1 : 0);
                                    ctx.cmd.SetRayTracingBufferParam(data.shader, Shader.PropertyToID("_RestirTemporalBuffer"), data.restirBuffer);
                                    ctx.cmd.SetRayTracingTextureParam(data.shader, Shader.PropertyToID("g_EnvTex"), data.envTexture);
                                    ctx.cmd.SetRayTracingTextureParam(data.shader, Shader.PropertyToID("g_Output"), data.output);

                                    ctx.cmd.DispatchRays(data.shader, "PathTracingRayGenShader", (uint)data.width, (uint)data.height, 1);
                                });
                            }
                        }

                        using (var builder = renderGraph.AddRasterRenderPass<BlitPassData>("Blit Path Tracing Result", out var passData, m_ProfilingSampler))
                        {
                            passData.blitMaterial = rayTracingResources.BlitMaterial;

                            passData.convergenceRatio = (float)convergenceStep / m_PathTracing.maximumSamples.value;

                            builder.UseTexture(frameTexture, AccessFlags.Read);
                            passData.sourceTexture = frameTexture;                            

                            builder.SetRenderAttachment(destination, 0, AccessFlags.Write);

                            builder.SetRenderFunc((BlitPassData data, RasterGraphContext rgContext) =>
                            {
                                passData.blitMaterial.SetFloat(Shader.PropertyToID("g_Ratio"), passData.convergenceRatio);

                                Blitter.BlitTexture(rgContext.cmd, data.sourceTexture, new Vector4(1, 1, 0, 0), data.blitMaterial, 0);
                            });
                        }
                    }
                }
            }
        }
    }
}