using JetBrains.Annotations;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[SerializeField]
public enum RayTracingStyle
{
    PATH_TRACING,
};

[CreateAssetMenu(menuName = "Rendering/RayTracingRenderPipelineAsset")]
public class RayTracingRenderPipelineAsset : RenderPipelineAsset
{
    [Header("Path Tracing Assets")]
    public RayTracingShader pathTracingShader;

    [Header("Environment Settings")]
    public Cubemap envTexture = null;

    [Header("Ray Bounces"), Range(1, 100)]
    public uint bounceCount = 8;

    [Header("Ray Tracing Style")]
    public RayTracingStyle rayTracingStyle = RayTracingStyle.PATH_TRACING;

    [Header("Active Cameras")]
    public CameraType activeCameraType;

    [Range(1, 100)]
    public uint bounceCountOpaque = 5;
    [Range(1, 100)]
    public uint bounceCountTransparent = 8;

    protected override RenderPipeline CreatePipeline() => new RayTracingRenderPipelineInstance(this);
}