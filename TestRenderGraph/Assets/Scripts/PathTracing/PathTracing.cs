using System;

namespace UnityEngine.Rendering.Universal
{
    [Serializable, VolumeComponentMenu("Post-processing/Path Tracing")]
    [SupportedOnRenderPipeline(typeof(UniversalRenderPipelineAsset))]
    public sealed partial class PathTracing : VolumeComponent, IPostProcessComponent
    {
        [Header("Path Tracing")]
        public BoolParameter enable = new BoolParameter(false);

        public TextureParameter envTexture = new TextureParameter(null);

        public EnumParameter<CameraType> activeCamera = new EnumParameter<CameraType>(CameraType.Game);

        public MinIntParameter bounceCount = new MinIntParameter(8, 0);

        public MinIntParameter maximumSamples = new MinIntParameter(2048, 1);

        public BoolParameter accumulation = new BoolParameter(true);

        public BoolParameter restir = new BoolParameter(false);

        public BoolParameter clearRestirBuffer = new BoolParameter(false);

        public BoolParameter debugMode = new BoolParameter(false);

        public bool IsActive() => enable.value;
    }

}