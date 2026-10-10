# Cupertino Foundation Models generator

Optional development-time generation for Flutter apps using
`cupertino_fundations_models`. **1.8.0 is available in the source repository; publication is separate.**
The companion is a dev dependency; core runtime dependencies remain Flutter only.

Annotate one concrete public model per library under `lib/` with `StructuredModel`
and optional `StructuredField` guides from the core annotation entry point.
Fields must be public final and match named parameters of a public generative
constructor. Explicit `dart run build_runner build` produces standalone
`model.structured.dart`, with `ModelCodec.schema`, `ModelCodec.decode` and
`ModelPartial`. No source-model edits, `part` directive or generated Swift are needed.

Use the core's existing structured generation and F04 decoder APIs. Partial
getters return `StructuredPartialField<T>` with presence, completeness and safe
value; they remain nonterminal and never construct final domain models.
Generation does not invoke models, download assets, call tools or change routing.

The bounded initial profile supports primitives, public enums, lists, annotated
nested classes and nullable choices. Manual/imported schemas remain available for
other contracts. Native null still requires OS26.4. Conversion checks structure,
not guide validity, source coverage, business truth or permission to write.

See [complete installation, choices, annotations and limits](../../doc/usage.md#optional-dart-generation)
and [annotated document example](../../example/lib/generated_document.dart).
An integrating agent asks once which route the user prefers when that choice is
missing, then respects it; do not install tooling or migrate models by default.

The checked-in `pubspec_overrides.yaml` resolves core from this local worktree.
For local tests:

```sh
flutter pub get
dart test --coverage coverage --reporter expanded
dart run coverage:format_coverage --lcov --in coverage --out coverage/lcov.info --report-on lib
python3 ../../.github/scripts/check_coverage.py
```

The companion remains 1.8.0 and its core ^1.8.0 dependency also accepts the
core 1.9.0 with F10 adapters. Their publication is separate; the core
release workflow only publishes core. Local
overrides are excluded from archives. The core workflow does not publish the generator.

The repository root excludes packages/ from the core archive. Pub applies ancestor
ignore files to nested publication, so stage the companion outside the repository:

```sh
python3 .github/scripts/stage_generator_package.py --local-core
```

Run that from the repository root; it prints a fresh staging directory. Only the
manifest, builder config, license, README/changelog and Dart sources are copied.
Run flutter pub publish --dry-run there. The local-core flag tests against the
unreleased core with an override excluded from the archive; pub reports a hint.
For separately authorized publication after core reaches pub.dev, stage without
that flag and resolve the public dependency. The script does not publish or
overwrite existing directories.
