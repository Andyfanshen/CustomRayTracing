# CustomRayTracing
Path Tracing with Unity RayTracing Shader

# 基本环境
- Unity URP工程（推荐[Unity 2023.1 beta](https://unity3d.com/beta)）
- 支持DX12硬件光追加速的显卡硬件（如RTX3080）

# 创建环境
- 通过Unity Hub创建3D(URP)项目
- 工程中选择 Edit-->Project Settings-->Other Settings-->Graphics APIs for Windows-->点击右下角`+`号添加`Direct3D12`，并将其拖拽至列表首位-->重启Unity编辑器
- Other Settings-->取消勾选`Static Batching`
- 使用本仓库的Assets文件夹替换工程的Assets文件夹
- Project Settings-->Graphics-->Scriptable Render Pipeline Settings选用`RayTracing (Ray Tracing Render Pipeline Asset)`
- Project Settings-->Quality-->点击`Add Quality Level`-->选中新建的Quality Level-->（可选）Name设置为`RayTracing`-->Render Pipeline Asset设置为`RayTracing (Ray Tracing Render Pipeline Asset)`

# 示例场景
- Project-->Assets-->Scene-->CornellBox
- Project-->Assets-->Scene-->ComplexBRDF

![cornellbox](https://github.com/Andyfanshen/CustomRayTracing/assets/33785908/6771aec0-c9db-45fd-b887-61dce9fd05ab)
![bike](https://github.com/Andyfanshen/CustomRayTracing/assets/33785908/d5ccd35f-bab4-4cbe-8105-cbb802036d99)
