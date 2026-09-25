# Local references

The DASP source is the [Seigyo import](../upstream/README.md). The Microsoft clone below is a separate comparison reference.

`agent-host-protocol/` is a full Git clone of Microsoft's reference repository. Its files are excluded from DASP source control.

Source: https://github.com/microsoft/agent-host-protocol

Reviewed revision: `296b25e7b698a4a84a0ee5a28d9573e70048a0bf`.

To recreate the reviewed checkout from the DASP root:

```sh
git clone https://github.com/microsoft/agent-host-protocol.git reference/agent-host-protocol
git -C reference/agent-host-protocol checkout 296b25e7b698a4a84a0ee5a28d9573e70048a0bf
```

See the [comparison notes](../docs/design/ahp-reference.md). The clone keeps its own Git history and license.
