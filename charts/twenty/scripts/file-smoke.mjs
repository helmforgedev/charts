// SPDX-License-Identifier: Apache-2.0
import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";

const hash = (bytes) => createHash("sha256").update(bytes).digest("hex");
export async function verifyAttachment({ base, origin, token, attachment }) {
  const recordResponse = await fetch(
    base + "/rest/attachments/" + attachment.id,
    {
      headers: { Authorization: "Bearer " + token, Host: new URL(origin).host },
      signal: AbortSignal.timeout(15000),
    },
  );
  assert.equal(recordResponse.status, 200);
  const locate = (value) =>
    value && typeof value === "object"
      ? value.id === attachment.id
        ? value
        : Object.values(value).map(locate).find(Boolean)
      : undefined;
  const found = locate(await recordResponse.json());
  assert.equal(found?.targetCompanyId, attachment.companyId);
  assert.ok(found.file.some((file) => file.fileId === attachment.fileId));
  const signed = new URL(attachment.url, origin);
  assert.equal(
    signed.origin,
    origin,
    "Native file proxy must keep storage credentials and private endpoints server-side",
  );
  const response = await fetch(base + signed.pathname + signed.search, {
    headers: { Host: new URL(origin).host },
    signal: AbortSignal.timeout(15000),
  });
  assert.equal(
    response.status,
    200,
    "Native signed attachment delivery failed",
  );
  assert.equal(
    hash(Buffer.from(await response.arrayBuffer())),
    attachment.hash,
  );
}

export async function attachmentSmoke({
  base,
  origin,
  graphql,
  token,
  companyId,
}) {
  let object, cursor;
  const names = [];
  for (let page = 0; page < 10; page++) {
    const objects = (
      await graphql(
        base,
        `query{objects(paging:{first:100${cursor ? ",after:" + JSON.stringify(cursor) : ""}}){pageInfo{hasNextPage endCursor} edges{node{nameSingular fieldsList{id name}}}}}`,
      )
    ).objects;
    names.push(...objects.edges.map((edge) => edge.node.nameSingular));
    object = objects.edges.find(
      (edge) => edge.node.nameSingular === "attachment",
    )?.node;
    if (object || !objects.pageInfo.hasNextPage) break;
    assert.ok(
      objects.pageInfo.endCursor && objects.pageInfo.endCursor !== cursor,
      "Metadata pagination must advance",
    );
    cursor = objects.pageInfo.endCursor;
  }
  const field = object?.fieldsList.find((field) => field.name === "file");
  assert.ok(
    field?.id,
    "Native attachment file metadata is required: " +
      JSON.stringify({
        objects: names,
        attachmentFields: object?.fieldsList.map((field) => field.name),
      }),
  );
  const bytes = Buffer.from(
    "HelmForge retained CRM attachment " + randomUUID() + "\n",
  );
  const query =
    "mutation($filename:String!,$size:Float!,$fieldId:String!){createFileUpload(filename:$filename,size:$size,fileFolder:FilesField,fieldMetadataId:$fieldId){fileId uploadUrl contentType}}";
  const variables = {
    filename: "owned-" + randomUUID() + ".txt",
    size: bytes.length,
    fieldId: field.id,
  };
  const denied = await graphql(base, query, variables, null, "/metadata", true);
  assert.ok(
    denied.errors?.length || denied.status === 401,
    "Anonymous upload allocation must fail",
  );
  const allocated = (await graphql(base, query, variables)).createFileUpload;
  const url = new URL(allocated.uploadUrl, origin);
  assert.equal(
    url.origin,
    origin,
    "Native upload proxy must stay on the configured application origin",
  );
  const uploaded = await fetch(base + url.pathname + url.search, {
    method: "PUT",
    headers: {
      Host: new URL(origin).host,
      "Content-Type": allocated.contentType,
      "Content-Length": String(bytes.length),
    },
    body: bytes,
    signal: AbortSignal.timeout(15000),
  });
  assert.ok(uploaded.ok, "Native attachment byte transfer failed");
  const completed = (
    await graphql(
      base,
      "mutation($id:String!){completeFileUpload(fileId:$id){id path size url}}",
      {
        id: allocated.fileId,
      },
    )
  ).completeFileUpload;
  assert.equal(Number(completed.size), bytes.length);
  const created = await graphql(
    base,
    "mutation($data:AttachmentCreateInput!){createAttachment(data:$data){id}}",
    {
      data: {
        targetCompanyId: companyId,
        file: [{ fileId: completed.id, label: variables.filename }],
      },
    },
    token,
    "/graphql",
  );
  const attachment = {
    id: created.createAttachment.id,
    companyId,
    fileId: completed.id,
    url: completed.url,
    path: completed.path,
    hash: hash(bytes),
  };
  await verifyAttachment({ base, origin, graphql, token, attachment });
  console.log(
    "PASS native attachment allocation, signed transfer, completion, company relation and exact download hash",
  );
  return attachment;
}
