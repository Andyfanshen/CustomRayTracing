using System;
using System.ComponentModel;

namespace UnityEngine.Rendering.Universal
{
    /// <summary>
    /// Settings class that stores the default volume profile for Volume Framework.
    /// </summary>
    [Serializable]
    [Category("Volume/Default Profile")]
    [SupportedOnRenderPipeline(typeof(UniversalRenderPipelineAsset))]
    public class URPDefaultVolumeProfileSettings : IDefaultVolumeProfileSettings
    {
        #region Version
        internal enum Version : int
        {
            Initial = 0,
        }

        [SerializeField][HideInInspector]
        Version m_Version;

        /// <summary>Current version.</summary>
        public int version => (int)m_Version;
        #endregion

        [SerializeField]
        VolumeProfile m_VolumeProfile;

        /// <summary>
        /// The default volume profile asset.
        /// </summary>
        public VolumeProfile volumeProfile
        {
            get => m_VolumeProfile;
            set => this.SetValueAndNotify(ref m_VolumeProfile, value);
        }
    }
}
