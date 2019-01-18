Shader "Hidden/Custom/Star"
{
    HLSLINCLUDE

        #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"
        #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/Colors.hlsl"
        #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/Sampling.hlsl"

        TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);

        float4 _MainTex_TexelSize;        
        float4 _MainTex_ST;

        int _TapCount;
        half _Intensity;
		half _Radian;
		half4 _Filter;
		float4 _BaseColor;
        float4 _ColorAberration;    
        float _Attenuation;
		
        // x: offsetU, y: offsetY, z: pathIndex
        float3 _Params;

        // 明度を返す
        half getBrightness(half3 color){
            return max(color.r, max(color.g, color.b));
        }

        half3 Sample (float2 uv) {
			return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).rgb;
		}

		half3 SampleBox (float2 uv, float delta) {
			float4 o = _MainTex_TexelSize.xyxy * float2(-delta, delta).xxyy;
			half3 s =
				Sample(uv + o.xy) + Sample(uv + o.zy) +
				Sample(uv + o.xw) + Sample(uv + o.zw);
			return s * 0.25f;
		}

		half3 Prefilter (half3 c) {
			half brightness = max(c.r, max(c.g, c.b));
			half soft = brightness - _Filter.y;
			soft = clamp(soft, 0, _Filter.z);
			soft = soft * soft * _Filter.w;
			half contribution = max(soft, brightness - _Filter.x);
			contribution /= max(brightness, 0.00001);
			return c * contribution;
		}

        float4 Frag(VaryingsDefault i) : SV_Target
        {
            float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);
            float luminance = dot(color.rgb, float3(0.2126729, 0.7151522, 0.0721750));
            color.rgb = lerp(color.rgb, luminance.xxx, _Intensity);
            return color;
        }

        float4 FragBoxDownPrefilterPass(VaryingsDefault i) : SV_Target
        {
            return half4(Prefilter(SampleBox(i.texcoord, 1)), 1);
        }
    ENDHLSL


    SubShader
    {
//        Tags{ "RenderPipeline" = "LightweightPipeline"}
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            Name "LUMI1"
            HLSLPROGRAM

                #pragma vertex VertDefault
                #pragma fragment Frag
            ENDHLSL
        }
        
        Pass
        {
            Name "BoxDownPrefilterPass"
            HLSLPROGRAM

                #pragma vertex VertDefault
                #pragma fragment FragBoxDownPrefilterPass
            ENDHLSL
        }

		Pass {
		    Blend One One

            Name "ApplyBloomPass"
			HLSLPROGRAM
				#pragma vertex VertDefault
				#pragma fragment FragmentProgram

				float4 FragmentProgram (VaryingsDefault i) : SV_Target {
                    return float4(Sample(i.texcoord), 1) * _Intensity;
				}
			ENDHLSL
		}
		
		Pass {

            Name "StarPass"
            
			HLSLPROGRAM
			
            #pragma vertex VertDefault
            #pragma fragment frag

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                half2 uvOffset : TEXCOORD1;
                half pathFactor : TEXCOORD2;
            };
            
            v2f vert (appdata v)
            {
                v2f o;
              o.vertex = float4(v.vertex.xy, 0.0, 1.0);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);                
//                o.texcoord = TransformTriangleVertexToUV(v.vertex.xy);
//                #if UNITY_UV_STARTS_AT_TOP
//                    o.texcoord = o.texcoord * float2(1.0, -1.0) + float2(0.0, 1.0);
//                #endif

                o.pathFactor = pow(4, _Params.z);
                o.uvOffset = half2(_Params.x, _Params.y) * _MainTex_TexelSize.xy * o.pathFactor;
                return o;
            }
   
            float4 frag (VaryingsDefault i) : SV_Target
            {
                half4 col = half4(0, 0, 0, 1);
                
                float factor = pow(4, _Params.z);
                float2 uvOffset = half2(_Params.x, _Params.y) * _MainTex_TexelSize.xy * factor;
                
                half2 uv = i.texcoord;
                for (float j = 0; j < _TapCount; j++) {
                    float3 tapColor = Sample(uv);
                    
                    if (j == 0) tapColor.r *= _ColorAberration.r;
                    else if (j == 1) tapColor.g *= _ColorAberration.g;
                    else if (j == 2) tapColor.b *= _ColorAberration.b;

                    col.rgb += tapColor * pow(_Attenuation, j * factor);
                    uv += uvOffset;
                }
                
                return col * _BaseColor;
            }

			ENDHLSL
		}
		
        Pass {

            Name "StarPassOptim"
            
			HLSLPROGRAM

            #pragma vertex VertDefault
            #pragma fragment frag

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                half2 uvOffset : TEXCOORD1;
                half pathFactor : TEXCOORD2;
            };
            
            v2f vert (appdata v)
            {
                v2f o;
              o.vertex = float4(v.vertex.xy, 0.0, 1.0);            
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);                
//                o.texcoord = TransformTriangleVertexToUV(v.vertex.xy);
//                #if UNITY_UV_STARTS_AT_TOP
//                    o.texcoord = o.texcoord * float2(1.0, -1.0) + float2(0.0, 1.0);
//                #endif

                o.pathFactor = pow(4, _Params.z);
                o.uvOffset = half2(_Params.x, _Params.y) * _MainTex_TexelSize.xy * o.pathFactor;
                return o;
            }
    
            float4 frag (VaryingsDefault i) : SV_Target
            {
                half4 col = half4(0, 0, 0, 1);
                
                float factor = pow(4, _Params.z);
                float2 uvOffset = half2(_Params.x, _Params.y) * _MainTex_TexelSize.xy * factor;
                
                half2 uv = i.texcoord;
                for (float j = 0; j < _TapCount; j++) {
                    float3 tapColor = Sample(uv);
                    
                    if (j == 0) tapColor.r *= _ColorAberration.r;
                    else if (j == 1) tapColor.g *= _ColorAberration.g;
                    else if (j == 2) tapColor.b *= _ColorAberration.b;

                    col.rgb += tapColor * pow(_Attenuation, j * factor);
                    uv += uvOffset;
                }
                
                // flip and reset UV
                uvOffset.x *= -1;
                uvOffset.y *= -1;
                uv = i.texcoord;
                
                for (float j = 0; j < _TapCount; j++) {
                    float3 tapColor = Sample(uv);
                    
                    if (j == 0) tapColor.r *= _ColorAberration.r;
                    else if (j == 1) tapColor.g *= _ColorAberration.g;
                    else if (j == 2) tapColor.b *= _ColorAberration.b;

                    col.rgb += tapColor * pow(_Attenuation, j * factor);
                    uv += uvOffset;
                }
                
                return col * _BaseColor;
            }

			ENDHLSL
		}		
		
    }
}