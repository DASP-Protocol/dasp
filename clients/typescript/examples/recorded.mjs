import { Client, decode, encode } from "../dist/index.js";

// A recorded reply adapter. This example does not connect to a server.
const client = new Client({
  source: "urn:example:client:one",
  hostSource: "urn:example:host:one",
  validateProfile: event => {
    if (event.type === "dasp.command.v1") {
      return event.data.name === "counter.add" && Number.isSafeInteger(event.data.input.amount) &&
        Object.keys(event.data.input).length === 1;
    }
    return event.type === "dasp.receipt.v1";
  },
  transport: async wire => {
    const request = decode(wire);
    return encode({
      specversion: "1.0", id: "recorded-receipt", source: "urn:example:host:one",
      type: "dasp.receipt.v1", datacontenttype: "application/json", requestid: request.requestid,
      data: { session_id: request.data.session_id, command_id: request.data.command_id,
        disposition: "accepted", admission_sequence: 1, error: null }
    });
  }
});
const session = {
  session_id: "session-counter", actor_id: "counter-main",
  profile: { id: "urn:example:dasp:counter", version: "1" }
};
const receipt = await client.submit(session, {
  command_id: "command-add-1", name: "counter.add", input: { amount: 3 }
});
if (receipt.data.disposition !== "accepted") throw Error("Unexpected receipt.");
console.log("Recorded receipt: accepted. Completion needs a saved outcome.");
