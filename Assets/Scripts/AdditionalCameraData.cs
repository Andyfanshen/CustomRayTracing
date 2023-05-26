using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

[RequireComponent(typeof(Camera))]
public class AdditionalCameraData : MonoBehaviour
{
    [HideInInspector]
    public int frameIndex = 0;

    [HideInInspector]
    public RenderTexture rayTracingOutput = null;

    private Camera _camera;

    private Matrix4x4 _prevCameraMatrix = Matrix4x4.zero;

    private void Start()
    {
        frameIndex = 0;

        _camera = GetComponent<Camera>();
    }

    public void UpdateCameraData()
    {
        frameIndex++;
    }

    public bool UpdateCameraResources()
    {
        if(_camera == null) _camera = GetComponent<Camera>();

        if (rayTracingOutput == null || rayTracingOutput.width != _camera.pixelWidth || rayTracingOutput.height != _camera.pixelHeight)
        {
            if (rayTracingOutput) rayTracingOutput.Release();

            var rtDesc = new RenderTextureDescriptor()
            {
                dimension = TextureDimension.Tex2D,
                width = _camera.pixelWidth,
                height = _camera.pixelHeight,
                depthBufferBits = 0,
                volumeDepth = 1,
                msaaSamples = 1,
                graphicsFormat = GraphicsFormat.R32G32B32A32_SFloat,
                enableRandomWrite = true,
            };

            rayTracingOutput = new RenderTexture(rtDesc);
            rayTracingOutput.Create();

            return true;
        }

        if(_camera.cameraToWorldMatrix != _prevCameraMatrix)
        {
            _prevCameraMatrix = _camera.cameraToWorldMatrix;
            return true;
        }

        return false;
    }

    private void OnDestroy()
    {
        if (rayTracingOutput != null)
        {
            rayTracingOutput.Release();
            rayTracingOutput = null;
        }
    }
}
