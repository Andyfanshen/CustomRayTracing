using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class InjectColorInvertPass : MonoBehaviour
{
    public Material InvertColorMaterial;
    public Material BlitColorMaterial;

    private ColorBlitPass m_ColorBlitPass = null;

    private void OnEnable()
    {
        CreateRenderPass();
        RenderPipelineManager.beginCameraRendering += InjectPass;
    }

    private void OnDisable()
    {
        RenderPipelineManager.beginCameraRendering -= InjectPass;
    }

    private void CreateRenderPass()
    {
        if(InvertColorMaterial == null || BlitColorMaterial == null)
        {
            Debug.Log("One or more materials are null.");
            return;
        }

        m_ColorBlitPass = new ColorBlitPass(InvertColorMaterial, BlitColorMaterial, RenderPassEvent.AfterRenderingSkybox);
    }

    private void InjectPass(ScriptableRenderContext renderContext, Camera currCamera)
    {
        if(m_ColorBlitPass == null)
        {
            CreateRenderPass();
        }

        if(currCamera.cameraType == CameraType.Game)
        {
            var data = currCamera.GetUniversalAdditionalCameraData();
            data.scriptableRenderer.EnqueuePass(m_ColorBlitPass);
        }
    }
}
