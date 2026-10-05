defmodule AnnotationsWeb.ApiTest do
  use AnnotationsWeb.ConnCase, async: true

  defp create_document(key \\ "dev-key-tenant-1") do
    api(key) |> post("/api/documents", %{title: "Lease agreement.pdf"}) |> json_response(201)
  end

  test "requires an API key" do
    conn = build_conn() |> get("/api/documents")
    assert json_response(conn, 401) == %{"error" => "invalid or missing API key"}
  end

  test "stores a batch and reads it back by page" do
    %{"id" => id} = create_document()

    items = [
      annotation(%{"page" => 0}),
      annotation(%{"page" => 4, "kind" => "note", "payload" => %{"text" => "Check clause 7"}})
    ]

    saved = api() |> post("/api/documents/#{id}/annotations/batch", %{annotations: items}) |> json_response(200)
    assert length(saved["saved"]) == 2

    page = api() |> get("/api/documents/#{id}/annotations?page=4") |> json_response(200)
    assert [%{"kind" => "note", "payload" => %{"text" => "Check clause 7"}}] = page["annotations"]
    assert page["next"] == nil
  end

  test "another tenant's document is indistinguishable from a missing one" do
    %{"id" => id} = create_document("dev-key-tenant-2")
    assert api() |> get("/api/documents/#{id}/annotations") |> json_response(404) == %{"error" => "document not found"}
    assert api() |> get("/api/documents/999999/annotations") |> json_response(404) == %{"error" => "document not found"}
  end

  test "explains invalid input" do
    %{"id" => id} = create_document()
    conn = api() |> post("/api/documents/#{id}/annotations/batch", %{annotations: [annotation(%{"kind" => "doodle"})]})
    assert %{"errors" => [%{"index" => 0, "errors" => %{"kind" => ["is invalid"]}}]} = json_response(conn, 422)

    assert api() |> get("/api/documents?limit=abc") |> json_response(400) == %{
             "error" => "limit must be a non-negative integer"
           }

    assert api() |> post("/api/documents/#{id}/annotations/batch", %{}) |> json_response(400)
  end
end
