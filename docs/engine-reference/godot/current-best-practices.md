# Godot — Current Best Practices

Last verified: 2026-05-17 | Engine: Godot 4.6

Practices that are **new or changed** since the model's training data (~4.3).
This supplements (not replaces) the agent's built-in knowledge.

## GDScript (4.5+)

- **Variadic arguments**: Functions can accept arbitrary parameter counts
  ```gdscript
  func log_values(prefix: String, values: Variant...) -> void:
      for v in values:
          print(prefix, ": ", v)
  ```

- **Abstract classes and methods**: Use `@abstract` to enforce inheritance
  ```gdscript
  @abstract
  class_name BaseEnemy extends CharacterBody3D

  @abstract
  func get_attack_pattern() -> Array[Attack]:
      pass  # Subclasses MUST override
  ```

- **Script backtracing**: Detailed call stacks available even in Release builds

## Physics (4.6)

- **Jolt Physics is the default 3D engine** for new projects
  - Better determinism and stability than GodotPhysics3D
  - Some HingeJoint3D properties (`damp`) only work with GodotPhysics
  - Switch: Project Settings → Physics → 3D → Physics Engine
  - 2D physics unchanged (still Godot Physics 2D)

## Rendering (4.6)

- **D3D12 is the default backend on Windows** (was Vulkan) — for better driver compatibility
- **Glow now processes before tonemapping** with screen blending mode — existing glow setups may look different
- **SSR overhauled** — significant improvement in realism, stability, and performance
- **AgX tonemapper** — new white point and contrast controls

## Rendering (4.5)

- **Shader Baker**: Pre-compile shaders to eliminate startup hitching
- **SMAA 1x**: New AA option — sharper than FXAA, cheaper than TAA
- **Stencil buffer**: Available for advanced masking/portal effects
- **Bent normal maps**: Directional occlusion in normal map textures
- **Specular occlusion**: Ambient occlusion now affects reflections

## Accessibility (4.5+)

- **Screen reader support**: Control nodes integrate with accessibility tools via AccessKit
- **Live translation preview**: Test GUI layouts in different languages directly in-editor
- **FoldableContainer**: New accordion-style UI node for collapsible sections
- **Recursive Control disable**: Disable mouse/focus interactions for entire node hierarchies with a single property

## Animation (4.5+)

- **BoneConstraint3D**: Bind bones to other bones with modifiers
  - AimModifier3D, CopyTransformModifier3D, ConvertTransformModifier3D

## Animation (4.6)

- **IK system fully restored**: Complete inverse kinematics reintroduced for 3D
  - Available modifiers: CCDIK, FABRIK, Jacobian IK, Spline IK, TwoBoneIK
  - Applied via `SkeletonModifier3D` nodes

## Resources (4.5+)

- **`duplicate_deep()`**: Explicit deep duplication for nested resource trees
  - Old `duplicate()` behavior retained for backward compatibility
  - Use `duplicate_deep()` when you need per-instance copies of nested resources

## Navigation (4.5+)

- **Dedicated 2D navigation server**: No longer proxied through 3D NavigationServer
  - Reduces export binary size for 2D-only games

## UI (4.6)

- **Dual-focus system**: Mouse/touch focus is now separate from keyboard/gamepad focus
  - Visual feedback differs depending on input method
  - Consider this when designing custom focus behavior

## Editor Workflow (4.6)

- Flexible dock drag-and-drop with blue outline preview (including bottom panel)
- Most panels support floating windows (except Debugger)
- New keyboard shortcuts: Alt+O (Output), Alt+S (Shader)
- Export variable auto-generation: drag resource from FileSystem into script editor
- Live preview in Quick Open dialog when "Live Preview" enabled
- New "Select Mode" (v key) prevents accidental transforms; old mode renamed "Transform Mode" (q key)

## Tooling

- **ripgrep has no `gdscript` type**: `*.gd` is registered under `gap` (GAP programming language).
  `rg --type gdscript` is a hard error — the search never executes.
  Always use `rg --glob "*.gd"` (shell) or `glob: "*.gd"` (Grep tool) to filter GDScript files.

## Platform (4.5+)

- **visionOS export**: First new platform since open-sourcing (windowed app mode)
- **SDL3 gamepad driver**: Better cross-platform gamepad support
- **Android**: Edge-to-edge display, camera feed access, 16KB page support (Android 15+)
- **Linux**: Wayland subwindow support for multi-window capability

## Android — Pratiques spécifiques (4.5–4.6)

- **16KB page support** (4.5+) : Requis pour Google Play ciblant Android 15+. Activé par défaut dans Godot 4.5+. Pour C# : .NET 9 minimum requis.
- **Capteurs désactivés par défaut** (depuis 4.4) : Activer explicitement dans Project Settings → Input Devices → Sensors si besoin (accéléromètre, gyroscope).
- **Storage Access Framework** (4.6) : Préférer SAF pour l'accès aux fichiers utilisateur — pas besoin de permissions MANAGE_EXTERNAL_STORAGE larges.
- **Scrcpy intégré** (4.6) : Godot peut lancer automatiquement l'export sur un device Android via scrcpy depuis l'éditeur.
- **GABE** (4.6) : Gradle Android Build Environment — construire des APK avec plugins Gradle directement depuis l'éditeur Godot.
- **Structure de build** : Depuis 4.6, les fichiers sources Android sont dans `android/build/src/main/java/` (pas `android/build/src/`).
- **Safe areas** : Utiliser `DisplayServer.get_display_safe_area()` pour gérer les notchs et barres de navigation. Toujours tester avec `adb shell wm overscan`.
- **Touch vs Mouse** : Godot 4 peut émuler des events souris depuis le touch. Désactiver si le jeu gère le touch nativement : Project Settings → Input Devices → Pointing → Emulate Mouse From Touch → Off.

## UI — Dual Focus System (4.6)

- Depuis 4.6, le focus souris/touch est **séparé** du focus clavier/gamepad.
- Les jeux mobiles (touch-only) ne nécessitent plus de gérer le focus clavier.
- Le feedback visuel (focus outline) s'affiche uniquement pour la navigation clavier/gamepad — pas pour le touch.
- Pour un jeu Android touch-only : pas besoin de configurer `focus_mode` sur les Control nodes sauf pour l'accessibilité.

## Resources — Duplication (4.5+)

- `duplicate()` : copie superficielle (ressources imbriquées **partagées**)
- `duplicate_deep()` : copie **profonde** de toute la hiérarchie de ressources
- `duplicate_deep(RESOURCE_DEEP_DUPLICATE_ALL)` : équivalent de l'ancien `duplicate(true)` en 4.4
- Règle : toujours utiliser `duplicate_deep()` pour les ressources qui ont des sous-ressources modifiables par instance (stats d'ennemi, inventaire, etc.)

## GDScript — Nouvelles features à adopter (4.5+)

- **`@abstract`** : Forcer l'héritage pour les classes de base (enemies, items, states...)
  ```gdscript
  @abstract
  class_name BaseState extends Node
  @abstract
  func enter() -> void: pass
  @abstract
  func exit() -> void: pass
  ```
- **Variadic args** : Utile pour les systèmes de log et d'événements
  ```gdscript
  func emit_event(event_name: StringName, data: Variant...) -> void:
      EventBus.dispatch(event_name, data)
  ```
- **Types statiques** : Toujours typer les variables et retours — le compilateur GDScript optimise les types connus
