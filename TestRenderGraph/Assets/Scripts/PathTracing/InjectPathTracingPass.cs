using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace UnityEngine.Rendering.Universal
{

    [ExecuteInEditMode]
    public class InjectPathTracingPass : MonoBehaviour
    {
        public PathTracingPass m_PathTracingPass = null;

        private void OnEnable()
        {
            RenderPipelineManager.beginCameraRendering += InjectPass;
        }

        private void OnDisable()
        {
            RenderPipelineManager.beginCameraRendering -= InjectPass;
        }

        private void CreateRenderPass()
        {
            if (!SystemInfo.supportsRayTracing)
            {
                Debug.Log("Ray Tracing API is not supported!");
                return;
            }

            m_PathTracingPass = new PathTracingPass(RenderPassEvent.BeforeRenderingPostProcessing);
        }

        private void InjectPass(ScriptableRenderContext renderContext, Camera currCamera)
        {
            var stack = VolumeManager.instance.stack;
            var pathTracingSettings = stack?.GetComponent<PathTracing>();
            if (stack == null || pathTracingSettings == null || !pathTracingSettings.enable.value)
            {
                return;
            }

            if (pathTracingSettings.envTexture.value == null)
            {
                Debug.LogWarning("Environment texture not set in Path Tracing Volume property!");
                return;
            }

            if (m_PathTracingPass == null)
            {
                CreateRenderPass();
            }

            if ((currCamera.cameraType & pathTracingSettings.activeCamera.value) > 0)
            {
                var data = currCamera.GetUniversalAdditionalCameraData();
                data.scriptableRenderer.EnqueuePass(m_PathTracingPass);
            }
        }
    }

}