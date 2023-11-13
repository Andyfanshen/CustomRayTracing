# CustomRayTracing
Path Tracing with Unity RayTracing Shader

## Requirements
- Unity URP Project (Recommend [Unity 2023.1 beta](https://unity3d.com/beta))
- Hardwares supported DXR (e.g. NVIDIA RTX serires)

## Quick Start
- Create a pure 3D URP project
- (In Editor) Edit-->Project Settings-->Other Settings-->Graphics APIs for Windows-->Click the '+' icon to add 'Direct3D12' API and drag it as the first one-->Restart Unity Editor to apply changes
- (In Editor) Edit-->Project Settings-->Other Settings-->**Deselect** 'Static Batching'
- Replace the assets folder with this repo's
- Project Settings-->Graphics-->Scriptable Render Pipeline Settings, Choose `RayTracing (Ray Tracing Render Pipeline Asset)`
- Project Settings-->Quality-->Click `Add Quality Level`-->Select the new added Quality Level-->(Optional) Rename it to `RayTracing`-->Set **Render Pipeline Asset** with `RayTracing (Ray Tracing Render Pipeline Asset)`

## Examples
- Assets-->Scene-->CornellBox
- Assets-->Scene-->ComplexBRDF

## Build
- Project Settings-->Quality-->Delete all quality levels other than `RayTracing`
- Edit-->File-->Build Settings-->Click `Add Open Scenes`-->Click `Build`

---

## 基本环境
- Unity URP工程（推荐[Unity 2023.1 beta](https://unity3d.com/beta)）
- 支持DX12硬件光追加速的显卡硬件（如RTX3080）

## 创建环境
- 通过Unity Hub创建3D(URP)项目
- 工程中选择 Edit-->Project Settings-->Other Settings-->Graphics APIs for Windows-->点击右下角`+`号添加`Direct3D12`，并将其拖拽至列表首位-->重启Unity编辑器
- Other Settings-->取消勾选`Static Batching`
- 使用本仓库的Assets文件夹替换工程的Assets文件夹
- Project Settings-->Graphics-->Scriptable Render Pipeline Settings选用`RayTracing (Ray Tracing Render Pipeline Asset)`
- Project Settings-->Quality-->点击`Add Quality Level`-->选中新建的Quality Level-->（可选）Name设置为`RayTracing`-->Render Pipeline Asset设置为`RayTracing (Ray Tracing Render Pipeline Asset)`

## 示例场景
- Project-->Assets-->Scene-->CornellBox
- Project-->Assets-->Scene-->ComplexBRDF

## 工程导出
- Project Settings-->Quality-->除`RayTracing`以外的Level全部删除
- Edit-->File-->Build Settings-->点击`Add Open Scenes`-->点击`Build`

---

## 渲染示例 Images
![cornellbox](https://github.com/Andyfanshen/CustomRayTracing/assets/33785908/6771aec0-c9db-45fd-b887-61dce9fd05ab)
![bike](https://github.com/Andyfanshen/CustomRayTracing/assets/33785908/d5ccd35f-bab4-4cbe-8105-cbb802036d99)
