Shader "PathTracingBlit"
{
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        ZWrite Off Cull Off

        Pass
        {
            Name "PathTracingBlitPass"

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            #pragma vertex Vert
            #pragma fragment Frag

            float g_Ratio;

            void AddConvergenceCue(float2 uv, inout float3 color)
            {
                if(g_Ratio >= 1)
                {
                    return;        
                }

                if(uv.y < 0.005 && uv.x <= g_Ratio)
                {
                    float lum = Luminance(color);
                    if(lum > 1.0)
                    {
                        color /= lum;
                        lum = 1.0;
                    }
                    // Make dark color brighter, and vice versa
                    color += lum > 0.5 ? -0.5 * lum : 0.05 + 0.5 * lum;
                }
            }

            float4 Frag(Varyings input) : SV_Target0
            {
                float2 uv = input.texcoord.xy;
                half4 color = SAMPLE_TEXTURE2D_X_LOD(_BlitTexture, sampler_LinearRepeat, uv, _BlitMipLevel);
                AddConvergenceCue(uv, color.xyz);

                return color;
            }

            ENDHLSL
        }
    }
}
