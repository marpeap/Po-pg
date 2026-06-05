# Godot — Breaking Changes

Last verified: 2026-05-17 (sources: docs.godotengine.org official migration guides)

Changes between Godot versions, focused on post-LLM-cutoff changes (4.4+).

---

## 4.5 → 4.6 (Jan 2026 — POST-CUTOFF, HIGH RISK)

### API Changes (GDScript-breaking)

| Subsystem | Change | Details |
|-----------|--------|---------|
| Core | `FileAccess.get_as_text()` | Paramètre `skip_cr` **supprimé** |
| Core | `FileAccess.create_temp()` | Paramètre `mode_flags` : `int` → `FileAccess.ModeFlags` |
| Core | `Performance.add_custom_monitor()` | Nouveau paramètre optionnel `type` |
| Animation | `AnimationPlayer` propriétés | `assigned_animation`, `autoplay`, `current_animation` : `String` → `StringName` |
| Animation | `AnimationPlayer.get_queue()` | Retour : `PackedStringArray` → `Array[StringName]` |
| Animation | Signal `current_animation_changed` | Paramètre `name` : `String` → `StringName` |
| Animation | `SpringBoneSimulator3D` enums | `BoneDirection` et `RotationAxis` migrées vers `SkeletonModifier3D` |
| Networking | `StreamPeerTCP` | Méthodes déplacées vers classe de base `StreamPeerSocket` |
| Networking | `TCPServer` | Méthodes déplacées vers classe de base `SocketServer` |
| OpenXR | `OpenXRExtensionWrapper._get_requested_extensions()` | Nouveau paramètre `xr_version` — casse GDScript et C# |
| Editor | `EditorFileDialog.add_side_menu()` | Méthode **supprimée** |
| Editor | `EditorFileDialog` | 17 méthodes/propriétés migrées vers la classe de base `FileDialog` |

### Changements de comportement

| Subsystem | Change | Details |
|-----------|--------|---------|
| Physics | Jolt est le moteur 3D par **défaut** | Nouveaux projets utilisent Jolt. Projets existants conservent leur réglage. `HingeJoint3D.damp` ne fonctionne qu'avec GodotPhysics. |
| Rendering | Glow s'applique **avant** le tonemapping | Était après. Scènes avec glow changeront d'apparence. Ajuster `glow_intensity` et `glow_blend_mode` dans WorldEnvironment. |
| Rendering | D3D12 par défaut sur Windows | Était Vulkan. Meilleure compatibilité driver. |
| Rendering | GLSL `view_matrix`/`inv_view_matrix` | Dans `SceneData` uniform : `mat4` → `mat3x4`. Shaders GLSL utilisant ces matrices doivent transposer leurs opérations. **Silent break** — aucune erreur de compilation, seulement corruption visuelle. |
| Rendering | Fog volumétrique mobile | Rendu significativement différent sur le renderer Mobile. |
| Core | `Quaternion` initialise à identity | Était zéro. Techniquement breaking mais rarement impactant. |
| UI | Dual-focus system | Focus souris/touch séparé du focus clavier/gamepad. Retour visuel différent selon input method. |
| Navigation | `AStar2D/3D.get_point_path()` | Retourne chemin vide si `from_id` est désactivé (était comportement indéfini). |
| Android | Structure de build réorganisée | Fichiers déplacés de `android/build/src/` → `android/build/src/main/java/`. |
| TSCN format | `load_steps` supprimé | N'est plus écrit dans les fichiers scène. IDs uniques ajoutés aux nœuds. |

### Nouvelles valeurs par défaut

| Propriété | Ancienne valeur | Nouvelle valeur |
|-----------|----------------|----------------|
| Rendering Windows | Vulkan | D3D12 |
| Physique 3D | GodotPhysics | Jolt Physics |
| `MeshInstance3D.skeleton` | `NodePath("..")` | `NodePath("")` |
| `Environment.glow_blend_mode` | 2 (Soft Light) | 1 (Screen) |
| `Environment.glow_intensity` | 0.8 | 0.3 |
| `PopupMenu.submenu_popup_delay` | 0.3s | 0.2s |
| Sky reflections roughness layers | 8 | 7 |

### Nouvelles features notables (4.6)

| Feature | Details |
|---------|---------|
| Animation IK | Complet restauré : `TwoBoneIK3D`, `FABRIK3D`, `CCDIK3D`, `JacobianIK3D` via `SkeletonModifier3D` |
| 2D TileMap | Scene tiles rotables (comme atlas tiles) |
| UI | `pivot_offset_ratio` : pivot normalisé (0-1) pour `Control`, indépendant de la taille |
| Android | Scrcpy : export Android direct depuis l'éditeur |
| Android | Storage Access Framework : accès fichiers granulaire sans permissions larges |
| Android | GABE : construction d'apps avec plugins Gradle depuis l'éditeur |
| Localisation | CSV : colonnes `?context` et `?plural` — plus besoin de Gettext pour pluriels |
| Debugger | Step Out : bouton pour quitter directement la fonction courante |
| Editor | LibGodot : intégrer le moteur dans d'autres applications |
| Plugins | `EditorDock` : container spécialisé pour les docks de plugins |
| Rendering | SSR complètement refait : meilleure gestion roughness et performances |
| Rendering | AgX tonemapper : nouveaux contrôles `agx_white` et `agx_contrast` |

---

## 4.4 → 4.5 (Late 2025 — POST-CUTOFF, HIGH RISK)

### API Changes (GDScript-breaking)

| Subsystem | Change | Details |
|-----------|--------|---------|
| Core | `JSONRPC.set_scope()` | **Renommée** `set_method()` — casse GDScript et C# |
| Core | `Node.get_rpc_config()` | **Renommée** `get_node_rpc_config()` — casse GDScript |
| Rendering | `RenderingServer.instance_reset_physics_interpolation()` | **Supprimée** — casse GDScript |
| Rendering | `RenderingServer.instance_set_interpolated()` | **Supprimée** — casse GDScript |
| Rendering | `RenderingDevice.Features` enum | `Address` renommé `BufferDeviceAddress` — casse C# |
| GLTF | `GLTFAccessor` propriétés | `byte_offset`, `count`, `sparse_*` : `int32` → `int64` (C# breaking) |
| GLTF | `GLTFBufferView` propriétés | `byte_length`, `byte_offset`, `byte_stride` : `int32` → `int64` (C# breaking) |
| Text | `TextServerExtension` méthodes | `_font_draw_glyph()`, `_shaped_text_draw()` + variants : ajout paramètre `oversampling` — casse GDScript et C# |

### Changements de comportement

| Subsystem | Change | Details |
|-----------|--------|---------|
| Resources | `Resource.duplicate(true)` | Duplique **uniquement ressources internes**. Utiliser `duplicate_deep(RESOURCE_DEEP_DUPLICATE_ALL)` pour l'ancien comportement 4.4. |
| Navigation | Mises à jour async par défaut | `NavigationServer` met à jour les régions en asynchrone |
| Physics (Jolt) | `Area3D` détecte static bodies | Par défaut — comportement différent de GodotPhysics |
| TileMap | `TileMapLayer.get_coords_for_body_rid()` | Résultats différents — physics chunking activé par défaut |
| Android C# | .NET 9 requis | Google Play exige le support 16KB pages pour Android 15+ |

### Nouvelles features notables (4.5)

| Feature | Details |
|---------|---------|
| GDScript | Variadic args : `func f(prefix: String, values: Variant...)` |
| GDScript | `@abstract` : classes et méthodes abstraites imposables |
| GDScript | Script backtracing : call stacks détaillés même en Release |
| Rendering | Shader Baker : pré-compile shaders (20x démarrage plus rapide) |
| Rendering | SMAA 1x : nouvelle option AA |
| Rendering | Stencil buffer : effets visuels avancés |
| Rendering | Bent normal maps, specular occlusion |
| Accessibility | Screen reader via AccessKit sur les nodes `Control` |
| Navigation | Serveur 2D dédié : exports plus légers pour jeux 2D |
| UI | `FoldableContainer` : node accordéon collapsible |
| UI | Disable récursif : désactiver mouse/focus sur toute une hiérarchie |
| Animation | `BoneConstraint3D` : `AimModifier3D`, `CopyTransformModifier3D`, `ConvertTransformModifier3D` |
| Resources | `duplicate_deep()` : duplication profonde explicite |
| Platform | Android 16KB page support (requis Google Play Android 15+) |
| Platform | SDL3 gamepad driver |

---

## 4.3 → 4.4 (Mid 2025 — NEAR CUTOFF, VERIFY)

| Subsystem | Change | Details |
|-----------|--------|---------|
| Core | `FileAccess.store_*` return `bool` | Was `void`. Methods: `store_8`, `store_16`, `store_32`, `store_64`, `store_buffer`, `store_csv_line`, `store_double`, `store_float`, `store_half`, `store_line`, `store_pascal_string`, `store_real`, `store_string`, `store_var` |
| Core | `OS.read_string_from_stdin()` | Nouveau paramètre `buffer_size` requis (défaut 1024 en 4.3) — **casse GDScript** |
| Core | `OS.execute_with_pipe` | Added optional `blocking` parameter |
| Core | `RegEx.compile/create_from_string` | Added optional `show_error` parameter |
| Rendering | `RenderingDevice.draw_list_begin` | Nombreux paramètres supprimés ; paramètre `breadcrumb` ajouté — **casse GDScript** |
| Rendering | `get/set_default_texture_parameter` | Type : `Texture2D` → `Texture` (paramètre et retour) |
| Rendering | `VisualShader` propriétés | `cube_map` : `Cubemap` → `TextureLayered`. `texture_array` : `Texture2DArray` → `TextureLayered` |
| GUI | `GraphEdit` signal `frame_rect_changed` | Paramètre `new_rect` : `Vector2` → `Rect2` — **casse GDScript et C#** |
| GUI | `RichTextLabel.push_meta` | Added optional `tooltip` parameter |
| GUI | `GraphEdit.connect_node` | Added optional `keep_alive` parameter |
| Export | `@export_file` | Stocke chemins comme `uid://` au lieu de `res://`. Tableaux sérialisés peuvent contenir des chemins mixtes. |
| CSG | Utilise Manifold | Géométrie non-manifold non supportée — peut casser des meshes CSG existants |
| Particles | `.restart()` method | Added optional `keep_seed` parameter (CPU/GPU 2D/3D) |
| Editor | `EditorTranslationParserPlugin._parse_file()` | Signature et type de retour complètement changés |
| Android | Capteurs désactivés par défaut | Accéléromètre etc. sont off par défaut — activer explicitement si besoin |

---

## 4.2 → 4.3 (In Training Data — LOW RISK)

| Subsystem | Change | Details |
|-----------|--------|---------|
| Animation | `Skeleton3D.add_bone` returns `int32` | Was `void` |
| Animation | `bone_pose_updated` signal | Replaced by `skeleton_updated` |
| TileMap | `TileMapLayer` replaces `TileMap` | One node per layer instead of multi-layer single node |
| Navigation | `NavigationRegion2D` | Removed `avoidance_layers`, `constrain_avoidance` properties |
| Editor | `EditorSceneFormatImporterFBX` | Renamed to `EditorSceneFormatImporterFBX2GLTF` |
| Animation | AnimationMixer base class | AnimationPlayer and AnimationTree now extend AnimationMixer |
