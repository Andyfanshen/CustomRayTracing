## Hybrid Ray Tracing for Unity URP pipeline (Unity URP 2023.3 beta+)
### Features
- Developed with [**RenderGraph API**](https://docs.unity3d.com/Packages/com.unity.render-pipelines.core@17.0/manual/render-graph-system.html)
- Path tracing pass **Injected** as volume component
- Support URP Lit.shader & ComplexLit.shader (Modified)
- Support Hybrid ray tracing (Path Tracing from G-Buffer)
- Support [Bounded VNDF sampling for smith-GGX reflection](https://dl.acm.org/doi/10.1145/3610543.3626163)
- Support temporal reuse ReSTIR (motion vector not used yet)

### Pictures

#### Sponza
2.1 Path Tracing result (raw, 1spp)
![图片](https://github.com/Andyfanshen/CustomRayTracing/assets/33785908/0560cb99-29b0-4d60-b4a3-97cc58eff785)

2.2 Path Tracing result (trace from G-Buffer, 1spp)
![图片](https://github.com/Andyfanshen/CustomRayTracing/assets/33785908/8edac66a-2fe8-46c3-85cb-e016c4ac8480)

2.3 Path Tracing result (temporal ReSTIR, 1spp)
![图片](https://github.com/Andyfanshen/CustomRayTracing/assets/33785908/10a7a898-5131-416e-bc3f-317bc38bd103)

2.4 Ground Truth (raw, 8192spp)
![图片](https://github.com/Andyfanshen/CustomRayTracing/assets/33785908/f3762057-3d7a-427f-9c75-ca3e461bf889)
