# Decal Renderer Feature

With the Decal Renderer Feature, Unity can project specific Materials (decals) onto other objects in the scene. The decals interact with the scene's lighting and wrap around Meshes.

![Sample scene without decals](Images/decal/decal-sample-without.png)<br/>*Sample scene without decals*

![Sample scene with decals](Images/decal/decal-sample-with.png)<br/>*Sample scene with decals. The decals hide the seams between materials and add artistic details.*

For examples of how to use Decals, refer to the [Decals samples in URP Package Samples](package-sample-urp-package-samples.md#decals).

## How to use the feature

To add decals to your scene:

1. [Add the Decal Renderer Feature](urp-renderer-feature-how-to-add.md) to the URP Renderer.

2. Create a Material, and assign it the `Shader Graphs/Decal` shader. In the Material, select the Base Map and the Normal Map.

    ![Example decal Material](Images/decal/decal-example-material.png)

3. Create a new Decal Projector GameObject, or add a [Decal Projector component](#decal-projector-component) to an existing GameObject.

The following illustration shows a Decal Projector in the scene.

![Decal Projector in the scene.](Images/decal/decal-projector-selected-with-inspector.png)

For more information, refer to the [Decal Projector component](#decal-projector-component).

<a name="decal-gameobject"></a>An alternative way to add decals to a scene:

1. Create a Quad GameObject.

2. Assign a Decal Material to the GameObject.

3. Position the Quad on the surface where you want the decal to be. If necessary, adjust the [mesh bias](decal-shader.md#mesh-bias-type) value to prevent z-fighting.

## Limitations

This feature has the following limitations:

* The decal projection does not work on transparent surfaces.

## Decal Renderer Feature properties

This section describes the properties of the Decal Renderer Feature.

![Decal Renderer Feature, Inspector view.](Images/decal/decal-rf-inspector.png)<br/>*Decal Renderer Feature, Inspector view.*

### Technique

Select the rendering technique for the Renderer Feature.

This section describes the options in this property.

#### Automatic

Unity selects the rendering technique automatically based on the build platform. The [Accurate G-buffer normals](rendering/deferred-rendering-path.md#accurate-g-buffer-normals) option is also taken into account, as it prevents normal blending from working correctly without the D-Buffer technique.

#### DBuffer

Unity renders decals into the Decal buffer (DBuffer). Unity overlays the content of the DBuffer on top of the opaque objects during the opaque rendering.

Selecting this technique reveals the **Surface Data** property. The Surface Data property lets you specify which surface properties of decals Unity blends with the underlying meshes. The Surface Data property has the following options:

* **Albedo**: decals affect the base color and the emission color.
* **Albedo Normal**: decals affect the base color, the emission color, and the normals.
* **Albedo Normal MAOS**: decals affect the base color, the emission color, the normals, the metallic values, the smoothness values, and the ambient occlusion values.

**Limitations:**

* This technique does not support the OpenGL and OpenGL ES API.

* This technique requires the DepthNormal prepass, which makes the technique less efficient on GPUs that implement tile-based rendering.

* This technique does not work on particles and terrain details.

#### <a name="screen-space-technique"></a>Screen Space

Unity renders decals after the opaque objects using normals that Unity reconstructs from the depth texture, or from the G-Buffer when using the Deferred rendering path. Unity renders decals as meshes on top of the opaque meshes. This technique supports only the normal blending. When using the Deferred rendering path with [Accurate G-buffer normals](rendering/deferred-rendering-path.md#accurate-g-buffer-normals), blending of normals is not supported, and will yield incorrect results.

Selecting this technique reveals the following properties.

| **Property**    | **Description** |
| --------------- |---------------- |
| **Normal Blend**| The options in this property (Low, Medium, and High) determine the number of samples of the depth texture that Unity takes when reconstructing the normal vector from the depth texture. The higher the quality, the more accurate the reconstructed normals are, and the higher the performance impact is. |
| &#160;&#160;&#160;&#160;**Low**    | Unity takes one depth sample when reconstructing normals. |
| &#160;&#160;&#160;&#160;**Medium** | Unity takes three depth samples when reconstructing normals. |
| &#160;&#160;&#160;&#160;**High**   | Unity takes five depth samples when reconstructing normals. |

### Max Draw Distance

The maximum distance from the Camera at which Unity renders decals.

### Use Rendering Layers

Select this check box to enable the [Rendering Layers](features/rendering-layers.md) functionality.

## Decal Projector component

The Decal Projector component lets Unity project decals onto other objects in the scene. A Decal Projector component must use a Material with the [Decal Shader Graph](decal-shader.md) assigned (`Shader Graphs/Decal`).

For more information on how to use the Decal Projector, refer to [How to use the feature](#how-to-use-the-feature).

The Decal Projector component contains the Scene view editing tools and the Decal Projector properties.

![Decal Projector component in the Inspector.](Images/decal/decal-projector-component-inspector.png)<br/>*Decal Projector component in the Inspector.*

> **Note**: If you assign a Decal Material to a GameObject directly (not via a Decal Projector component), then Decal Projectors do not project decals on such GameObject.

### Decal Scene view editing tools

When you select a Decal Projector, Unity shows its bounds and the projection direction.

The Decal Projector draws the decal Material on every Mesh inside the bounding box.

The white arrow shows the projection direction. The base of the arrow is the pivot point.

![Decal Projector bounding box](Images/decal/decal-projector-bounding-box.png)

The Decal Projector component provides the following Scene view editing tools.

![Scene view editing tools](Images/decal/decal-scene-view-editing-tools.png)

| **Icon**                                     | **Action**    | **Description** |
| -------------------------------------------- |-------------- | --------------- |
|![](Images/decal/decal-projector-scale.png)   | **Scale**     | Select to scale the projector box and the decal. This tool changes the UVs of the Material to match the size of the projector box. The tool does not affect the pivot point. |
|![](Images/decal/decal-projector-crop.png)    | **Crop**      | Select to crop or tile the decal with the projector box. This tool changes the size of the projector box but not the UVs of the Material. The tool does not affect the pivot point. |
|![](Images/decal/decal-projector-pivotuv.png) | **Pivot / UV**| Select to move the pivot point of the decal without moving the projection box. This tool changes the transform position.<br/>This tool also affects the UV coordinates of the projected texture. |

### Decal Projector component properties

This section describes the Decal Projector component properties.

| **Property**            | **Description**                                              |
| ----------------------- | ------------------------------------------------------------ |
| **Scale Mode**          | Select whether this Decal Projector inherits the Scale values from the Transform component of the root GameObject.<br/>Options:<br/>&#8226; **Scale Invariant**: Unity uses the scaling values (Width, Height, etc.) only in this component, and ignores the values in the root GameObject.<br/>&#8226; **Inherit from Hierarchy**: Unity evaluates the scaling values for the decal by multiplying the [lossy Scale](https://docs.unity3d.com/ScriptReference/Transform-lossyScale.html) values of the Transform of the root GameObject by the Decal Projector's scale values.<br/>**Note**: since the Decal Projector uses the orthogonal projection, if the root GameObject is [skewed](https://docs.unity3d.com/Manual/class-Transform.html), the decal does not scale correctly. |
| **Width**               | The width of the projector bounding box. The projector scales the decal to match this value along the local X axis. |
| **Height**              | The height of the projector bounding box. The projector scales the decal to match this value along the local Y axis. |
| **Projection Depth**    | The depth of the projector bounding box. The projector projects decals along the local Z axis. |
| **Pivot**               | The offset position of the center of the projector bounding box relative to the origin of the root GameObject. |
| **Material**            | The Material to project. The Material must use a Shader Graph that has the Decal Material type. For more information, refer to the page [Decal Shader Graph](decal-shader.md). |
| **Tiling**              | The tiling values for the decal Material along its UV axes. |
| **Offset**              | The offset values for the decal Material along its UV axes. |
| **Opacity**             | This property lets you specify the opacity value. A value of 0 makes the decal fully transparent, a value of 1 makes the decal as opaque as defined by the **Material**. |
| **Draw Distance**       | The distance from the Camera to the Decal at which this projector stops projecting the decal and URP no longer renders the decal. |
| **Start Fade**          | Use the slider to set the distance from the Camera at which the projector begins to fade out the decal. Values from 0 to 1 represent a fraction of the **Draw Distance**. With a value of 0.9, Unity starts fading the decal out at 90% of the **Draw Distance** and finishes fading it out at the **Draw Distance**. |
| **Angle Fade**          | Use the slider to set the fade out range of the decal based on the angle between the decal's backward direction and the vertex normal of the receiving surface. |

## Performance

Decals do not support the **SRP Batcher** by design because they use Material property blocks. To reduce the number of draw calls, decals can be batched together using GPU instancing. If the decals in your scene use the same Material, and if the Material has the **Enable GPU Instancing** property turned on, Unity instances the Materials and reduces the number of draw calls.

To reduce the number of Materials necessary for decals, put multiple decal textures into one texture (atlas). Use the UV offset properties on the decal projector to determine which part of the atlas to display.

The following image shows an example of a decal atlas.

![Decal Atlas](Images/decal/decal-atlas.png) <br/> *left: decal atlas with four decals. Right: a decal projector is projecting one of them. If the decal Material has GPU instancing enabled, any instance of the four decals is rendered in a single instanced draw call.*
