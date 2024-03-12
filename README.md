## Hybrid Ray Tracing for Unity URP pipeline (Unity URP 2023.3 beta+)
### Features
- Developed with **RenderGraph API**
- Path tracing pass **Injected** as volume component
- Support URP Lit.shader & ComplexLit.shader (Modified)
- Support Hybrid ray tracing (Path Tracing from G-Buffer)
- Support temporal reuse ReSTIR (motion vector not used yet)

### Pictures
#### Cornell Box
1.1 Raster result
![图片](https://github.com/Andyfanshen/CustomRayTracing/assets/33785908/817e2d67-7b69-47bf-b7b9-9496197fca26)

1.2 Path Tracing result (1spp)
![图片](https://github.com/Andyfanshen/CustomRayTracing/assets/33785908/3947478e-d615-4714-aec4-234c986eb915)

1.3 Path Tracing result (temporal ReSTIR, 1spp)
![图片](https://github.com/Andyfanshen/CustomRayTracing/assets/33785908/f0b96b72-d3b1-4b75-a935-957712776a29)

1.4 Ground Truth (1024spp)
![图片](https://github.com/Andyfanshen/CustomRayTracing/assets/33785908/f1ab7d25-e954-4df0-98c3-b7cdab050e43)

#### Sponza
2.1 Raster result
![图片](https://github.com/Andyfanshen/CustomRayTracing/assets/33785908/65fd9349-a78b-43ac-869b-499a4e94e5e0)

2.2 Path Tracing result (1spp)
![图片](https://github.com/Andyfanshen/CustomRayTracing/assets/33785908/9740796d-de8a-44fd-bc31-c5c7f10e70f7)

2.3 Path Tracing result (temporal ReSTIR, 1spp)
![图片](https://github.com/Andyfanshen/CustomRayTracing/assets/33785908/1fc245e6-ddb4-4d1c-81fb-80baa6ecbcb2)

2.4 Ground Truth (1024spp)
![图片](https://github.com/Andyfanshen/CustomRayTracing/assets/33785908/99f91b47-3c43-44f0-8264-9cb4cf6985c9)
