using System;
using System.ComponentModel;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable]
[HideInInspector]
[Category("Resources/Ray Tracing")]
[SupportedOnRenderPipeline(typeof(UniversalRenderPipelineAsset))]
public class RayTracingResources : IRenderPipelineResources
{
    public int version => 0;

#if UNITY_EDITOR
    [SerializeField, ResourcePath("Assets/Scripts/PathTracing/Shaders/PathTracingBlit.shader")]
    private Shader blitShader;
    public Material BlitMaterial
    {
        get => new Material(blitShader);
    }

    [SerializeField, ResourcePath("Assets/Scripts/PathTracing/Shaders/DebugBlit.shader")]
    private Shader debugBlitShader;
    public Material DebugBlitMaterial
    {
        get => new Material(debugBlitShader);
    }

    #region Path Tracing
    [Header("Path Tracing")]
    [SerializeField, ResourcePath("Assets/Scripts/PathTracing/Shaders/PathTracing.raytrace")]
    private RayTracingShader m_PathTracingRT;
    public RayTracingShader PathTracingRT
    {
        get => m_PathTracingRT;
        set => this.SetValueAndNotify(ref m_PathTracingRT, value);
    }
    #endregion

    #region ReSTIR
    [SerializeField, ResourcePath("Assets/Scripts/PathTracing/Shaders/ReSTIR.compute")]
    private ComputeShader m_ReSTIRCS;
    public ComputeShader ReSTIRCS
    {
        get => m_ReSTIRCS;
        set => this.SetValueAndNotify(ref m_ReSTIRCS, value);
    }
    #endregion
#else
    [SerializeField, ResourcePath("Runtime/RenderPipelineResources/PathTracing/Shaders/PathTracingBlit.shader")]
    private Shader blitShader;
    public Material BlitMaterial
    {
        get => new Material(blitShader);
    }

    [SerializeField, ResourcePath("Runtime/RenderPipelineResources/PathTracing/Shaders/DebugBlit.shader")]
    private Shader debugBlitShader;
    public Material DebugBlitMaterial
    {
        get => new Material(debugBlitShader);
    }

    #region Path Tracing
    [Header("Path Tracing")]
    [SerializeField, ResourcePath("Runtime/RenderPipelineResources/PathTracing/Shaders/PathTracing.raytrace")]
    private RayTracingShader m_PathTracingRT;
    public RayTracingShader PathTracingRT
    {
        get => m_PathTracingRT;
        set => this.SetValueAndNotify(ref m_PathTracingRT, value);
    }
    #endregion

    #region ReSTIR
    [SerializeField, ResourcePath("Runtime/RenderPipelineResources/PathTracing/Shaders/ReSTIR.compute")]
    private ComputeShader m_ReSTIRCS;
    public ComputeShader ReSTIRCS
    {
        get => m_ReSTIRCS;
        set => this.SetValueAndNotify(ref m_ReSTIRCS, value);
    }
    #endregion
#endif
}
