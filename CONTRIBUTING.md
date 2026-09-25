# Contributing

Start with the imported Seigyo contract. Preserve the distinction between current coding v1, approved opt-in initialization, draft schemas, and proposed behavior.

Keep imported files unchanged. Make DASP extraction changes outside `upstream/seigyo/`, with source references and a compatibility decision. Keep original Signal names, requirement IDs, and frozen contract bytes until a versioned migration explicitly changes them.

A protocol change needs language-independent schemas, custom validation rules, examples, and shared conformance cases. Elixir and TypeScript must implement the same contract. A package version is not a protocol version.

Run the import check and frozen contract check before accepting changes. Record which portable tests and live tests ran. Do not treat imported historical reports as new test results.
