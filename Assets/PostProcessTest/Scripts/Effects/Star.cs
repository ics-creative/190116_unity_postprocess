namespace UnityEngine.Rendering.PostProcessing
{
    using System;
    using UnityEngine;
    using UnityEngine.Rendering.PostProcessing;

    [Serializable]
    [PostProcess(typeof(StarRenderer), PostProcessEvent.AfterStack, "Custom/Star")]
    public sealed class Star : PostProcessEffectSettings
    {
        // シェーダーパスモード
        [SerializeField, Range(0, 1)] public IntParameter ShaderPassMode = new IntParameter {value = 1};

        [SerializeField, Range(0, 8)] public IntParameter numStars = new IntParameter {value = 3};

        [SerializeField, Range(0, 10)] public FloatParameter intensity = new FloatParameter {value = 1.5f};

        [SerializeField, Range(0.5f, 0.99f)] public FloatParameter attenuation = new FloatParameter {value = 0.95f};

        [SerializeField, Range(0, 50)] public FloatParameter threshold = new FloatParameter {value = 3.0f};

        [SerializeField, Range(0, 1)] public FloatParameter softThreshold = new FloatParameter {value = 0.5f};

        [SerializeField, Range(0.1f, 1.0f)] public FloatParameter resolution = new FloatParameter {value = 0.25f};

        [SerializeField, Range(0.0f, 360.0f)] public FloatParameter startAngle = new FloatParameter {value = 30.0f};

        // Streakを伸ばす回数
        [SerializeField, Range(1, 4)] public IntParameter iterationCount = new IntParameter {value = 2};

        // 1DrawでのTap回数
        [SerializeField, Range(1, 30)] public IntParameter TapCount = new IntParameter {value = 20};

        [SerializeField] public ColorParameter baseColor = new ColorParameter {value = Color.white};

        [SerializeField] public ColorParameter colorAberration = new ColorParameter {value = Color.red};
    }

    public sealed class StarRenderer : PostProcessEffectRenderer<Star>
    {
        const int debugPass = 0;
        const int BoxDownPrefilterPass = 1;
        const int ApplyBloomPass = 2;
        const int StarPass = 3;
        const int StarPassOptim = 4;

        public override void Render(PostProcessRenderContext context)
        {
            var sheet = context.propertySheets.Get(Shader.Find("Hidden/Custom/Star"));

            // input shader param
            var threshold = settings.threshold;
            var softThreshold = settings.softThreshold;
            var intensity = settings.intensity;
            var attenuation = settings.attenuation;
            var TapCount = settings.TapCount;
            var baseColor = settings.baseColor;
            var colorAberration = settings.colorAberration;

            var knee = threshold * softThreshold;
            Vector4 filter;
            filter.x = threshold;
            filter.y = filter.x - knee;
            filter.z = 2f * knee;
            filter.w = 0.25f / (knee + 0.00001f);
            sheet.properties.SetVector("_Filter", filter);
            sheet.properties.SetFloat("_Intensity", Mathf.GammaToLinearSpace(intensity));
            sheet.properties.SetFloat("_Attenuation", Mathf.GammaToLinearSpace(attenuation));
            sheet.properties.SetInt("_TapCount", TapCount);
            sheet.properties.SetColor("_BaseColor", baseColor);
            sheet.properties.SetColor("_ColorAberration", colorAberration);

            // TODO: enum
//          case StarEffectMode.nStar:
//          case StarEffectMode.doubleDraw:

            // draw
            switch (settings.ShaderPassMode)
            {
                case 0:
                    drawNStar(context, sheet, StarPass);
                    break;
                case 1:
                    drawNStar(context, sheet, StarPassOptim);
                    break;
            }
        }

        void drawNStar(PostProcessRenderContext context, PropertySheet sheet, int shaderPass)
        {
            var cmd = context.command;
            cmd.BeginSample("drawNStar");

            // test
//            context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);
//            context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, BoxDownPrefilterPass);
//            context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, ApplyBloomPass);
//            context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, StarPass);

            var paramsId = Shader.PropertyToID("_Params");
            int width = (int) (context.width * settings.resolution);
            int height = (int) (context.height * settings.resolution);

            var tempRT1 = RenderTexture.GetTemporary(width, height);
            var tempRT2 = RenderTexture.GetTemporary(width, height);

            // ソースをdestinationに退避
            cmd.BlitFullscreenTriangle(context.source, context.destination);

            // n方向にスターを作るループ        
            var num = settings.numStars;
            var rad = settings.startAngle * (3.14f / 180);
            for (int i = 0; i < num; i++)
            {
                // 明度
                context.command.BlitFullscreenTriangle(context.source, tempRT1, sheet, BoxDownPrefilterPass);

                var currentSrc = tempRT1;
                var currentTarget = tempRT2;

                // UV座標オフセット
                var parameters = Vector3.zero;
                parameters.x = (float) Math.Cos(rad);
                parameters.y = (float) Math.Sin(rad);

                // 角度を増分
                if (settings.ShaderPassMode == 0)
                {
                    rad += (float) (6.28f / num);
                }
                else
                {
                    rad += (float) (3.14f / num);                    
                }

                // Streakの作成
                for (int j = 0; j < settings.iterationCount; j++)
                {
                    parameters.z = j;
                    sheet.properties.SetVector("_Params", parameters);

                    // ピンポンレンダリング
                    context.command.BlitFullscreenTriangle(currentSrc, currentTarget, sheet, shaderPass);
                    var tmp = currentSrc;
                    currentSrc = currentTarget;
                    currentTarget = tmp;
                }

                // 加算合成
                context.command.BlitFullscreenTriangle(currentSrc, context.destination, sheet, ApplyBloomPass);
            }

            // RenderTextureを開放する
            RenderTexture.ReleaseTemporary(tempRT1);
            RenderTexture.ReleaseTemporary(tempRT2);

            cmd.EndSample("drawNStar");
        }
    }
}