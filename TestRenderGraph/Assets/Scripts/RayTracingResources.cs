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

    [SerializeField, ResourcePath("Scripts/PathTracing/Shaders/PathTracingBlit.shader")]
    private Shader blitShader;
    public Material BlitMaterial
    {
        get => new Material(blitShader);
    }

    [SerializeField, ResourcePath("Scripts/PathTracing/Shaders/DebugBlit.shader")]
    private Shader debugBlitShader;
    public Material DebugBlitMaterial
    {
        get => new Material(debugBlitShader);
    }

    #region Path Tracing
    [Header("Path Tracing")]
    [SerializeField, ResourcePath("Scripts/PathTracing/Shaders/PathTracing.raytrace")]
    private RayTracingShader m_PathTracingRT;
    public RayTracingShader PathTracingRT
    {
        get => m_PathTracingRT;
        set => this.SetValueAndNotify(ref m_PathTracingRT, value);
    }
    #endregion
}
