#if UNITY_EDITOR

using UnityEngine;
using UnityEditor;

public class UberShaderGUI : ShaderGUI
{
    MaterialEditor m_MaterialEditor;

    MaterialProperty albedoTex = null;
    MaterialProperty colorValue = null;
    MaterialProperty metallicValue = null;
    MaterialProperty smoothnessValue = null;
    MaterialProperty specularColor = null;
    MaterialProperty normalTex = null;
    MaterialProperty metallicTex = null;
    MaterialProperty iorValue = null;

    MaterialProperty transparentState = null;
    MaterialProperty extinctionValue = null;

    MaterialProperty emissionState = null;
    MaterialProperty emissionTex = null;
    MaterialProperty emissionColor = null;

    private static class UberShaderContents
    {
        public static GUIContent albedoText = EditorGUIUtility.TrTextContent("Albedo", "Albedo (RGB)");
        public static GUIContent emissionText = EditorGUIUtility.TrTextContent("Color", "Emission (RGB)");
        public static GUIContent normalText = EditorGUIUtility.TrTextContent("Normal", "Normal Map (Bump)");
        public static GUIContent metallicText = EditorGUIUtility.TrTextContent("Metallic", "Metallic Roughness Map (RGBA)");
    }

    public void FindProperty(MaterialProperty[] props)
    {
        albedoTex = FindProperty("_MainTex", props);
        colorValue = FindProperty("_Color", props);
        metallicValue = FindProperty("_Metallic", props);
        smoothnessValue = FindProperty("_Glossiness", props);
        normalTex = FindProperty("_NormalMap", props);
        metallicTex = FindProperty("_MetallicMap", props);
        iorValue = FindProperty("_IOR", props);

        transparentState = FindProperty("_Transparent", props);
        extinctionValue = FindProperty("_ExtinctionCoefficient", props);

        emissionState = FindProperty("_Emission", props);
        emissionTex = FindProperty("_EmissionTex", props);
        emissionColor = FindProperty("_EmissionColor", props);
    }

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        FindProperty(properties);

        m_MaterialEditor = materialEditor;

        Material material = materialEditor.target as Material;

        ShaderPropertiesGUI(material);
    }

    private void UpdateMaterialKeyword(Material material, string keyword, bool state)
    {
        if (state) material.EnableKeyword(keyword);
        else material.DisableKeyword(keyword);
    }

    public void ShaderPropertiesGUI(Material material)
    {
        EditorGUIUtility.labelWidth = 0;

        EditorGUI.BeginChangeCheck();

        m_MaterialEditor.TexturePropertySingleLine(UberShaderContents.albedoText, albedoTex, colorValue);

        EditorGUI.indentLevel = 1;
        m_MaterialEditor.TextureScaleOffsetProperty(albedoTex);
        EditorGUI.indentLevel = 0;

        m_MaterialEditor.TexturePropertySingleLine(UberShaderContents.metallicText, metallicTex);
        m_MaterialEditor.TexturePropertySingleLine(UberShaderContents.normalText, normalTex);

        m_MaterialEditor.RangeProperty(smoothnessValue, "Smoothness");
        m_MaterialEditor.RangeProperty(metallicValue, "Metallic");
        m_MaterialEditor.RangeProperty(iorValue, "Index Of Refraction");

        bool isTransparent = transparentState.floatValue != 0.0f;
        isTransparent = EditorGUILayout.Toggle("Transparent", isTransparent);
        if (isTransparent)
        {
            EditorGUI.indentLevel = 1;
            m_MaterialEditor.RangeProperty(extinctionValue, "Extinction Coefficient");
            EditorGUI.indentLevel = 0;
        }

        bool isEmission = emissionState.floatValue != 0.0f;
        isEmission = EditorGUILayout.Toggle("Emission", isEmission);
        if (isEmission)
        {
            m_MaterialEditor.TexturePropertyWithHDRColor(UberShaderContents.emissionText, emissionTex, emissionColor, false);

            EditorGUI.indentLevel = 1;
            m_MaterialEditor.TextureScaleOffsetProperty(emissionTex);
            EditorGUI.indentLevel = 0;
        }

        if (EditorGUI.EndChangeCheck())
        {
            transparentState.floatValue = isTransparent ? 1.0f : 0.0f;
            emissionState.floatValue = isEmission ? 1.0f : 0.0f;

            UpdateMaterialKeyword(material, "_TRANSPARENT", isTransparent);
            UpdateMaterialKeyword(material, "_EMISSION", isEmission);

            bool withMetallicMap = material.GetTexture("_MetallicMap") != null;
            UpdateMaterialKeyword(material, "_METALLICMAP", withMetallicMap);

            bool withNormalMap = material.GetTexture("_NormalMap") != null;
            UpdateMaterialKeyword(material, "_NORMALMAP", withNormalMap);
        }
    }
}
#endif