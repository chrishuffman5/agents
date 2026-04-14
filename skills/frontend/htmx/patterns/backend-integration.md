# HTMX Backend Integration Patterns

Patterns for integrating HTMX with Django, Flask, Rails, ASP.NET, Go, and FastAPI.

---

## Universal Pattern: HX-Request Detection

Every backend checks the `HX-Request` header to return a fragment or a full page:

```
if HX-Request header present:
    return rendered HTML partial (fragment)
else:
    return full page (layout + content)
```

---

## Django

```python
from django.shortcuts import render, get_object_or_404
from django.http import HttpResponse

def item_list(request):
    items = Item.objects.order_by("-created_at")
    template = "partials/item_list.html" if request.headers.get("HX-Request") else "items.html"
    return render(request, template, {"items": items})

def create_item(request):
    if request.method == "POST":
        item = Item.objects.create(name=request.POST["name"])
        response = render(request, "partials/item_row.html", {"item": item})
        response["HX-Trigger"] = "itemCreated"
        return response

def delete_item(request, pk):
    item = get_object_or_404(Item, pk=pk)
    item.delete()
    return HttpResponse(status=204)
```

**CSRF:** `<body hx-headers='{"X-CSRFToken": "{{ csrf_token }}"}'>`

---

## Flask

```python
from flask import Flask, request, render_template, Response

app = Flask(__name__)

@app.route("/search")
def search():
    q = request.args.get("q", "")
    results = db.session.execute(
        db.select(Item).where(Item.name.ilike(f"%{q}%"))
    ).scalars().all()
    if request.headers.get("HX-Request"):
        return render_template("partials/results.html", results=results, q=q)
    return render_template("search.html", results=results, q=q)

@app.route("/items/<int:pk>", methods=["DELETE"])
def delete_item(pk):
    item = Item.query.get_or_404(pk)
    db.session.delete(item)
    db.session.commit()
    return Response(status=204)
```

---

## Rails

```ruby
# app/controllers/items_controller.rb
class ItemsController < ApplicationController
  def index
    @items = Item.order(created_at: :desc)
    if request.headers["HX-Request"]
      render partial: "items/list", locals: { items: @items }
    else
      render :index
    end
  end

  def create
    @item = Item.new(item_params)
    if @item.save
      render partial: "items/item", locals: { item: @item }, status: :created
    else
      render partial: "items/form", locals: { item: @item }, status: :unprocessable_entity
    end
  end

  def destroy
    Item.find(params[:id]).destroy
    head :no_content
  end
end
```

**CSRF:** `<body hx-headers='{"X-CSRF-Token": "<%= form_authenticity_token %>"}'>`

---

## ASP.NET

```csharp
[HttpGet("items")]
public IActionResult Items()
{
    var items = _db.Items.OrderByDescending(i => i.CreatedAt).ToList();
    if (Request.Headers.ContainsKey("HX-Request"))
        return PartialView("_ItemList", items);
    return View(items);
}

[HttpDelete("items/{id}")]
public IActionResult DeleteItem(int id)
{
    var item = _db.Items.Find(id);
    if (item == null) return NotFound();
    _db.Items.Remove(item);
    _db.SaveChanges();
    return NoContent();
}
```

**CSRF:** Use `@Html.AntiForgeryToken()` inside forms, or set `hx-headers` with the token.

```html
<button hx-delete="/items/@item.Id"
        hx-target="closest li"
        hx-swap="delete"
        hx-headers='{"RequestVerificationToken": "@GetAntiForgeryToken()"}'>
  Delete
</button>
```

---

## Go

```go
func itemsHandler(w http.ResponseWriter, r *http.Request) {
    items := fetchItems(db)
    if r.Header.Get("HX-Request") == "true" {
        tmpl.ExecuteTemplate(w, "item-list", items)
        return
    }
    tmpl.ExecuteTemplate(w, "full-page", items)
}

func deleteHandler(w http.ResponseWriter, r *http.Request) {
    id := chi.URLParam(r, "id")
    db.Delete(id)
    w.WriteHeader(http.StatusNoContent)
}
```

---

## FastAPI

```python
from fastapi import FastAPI, Request, Header
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

app = FastAPI()
templates = Jinja2Templates(directory="templates")

@app.get("/items", response_class=HTMLResponse)
async def items(request: Request, hx_request: str | None = Header(default=None)):
    items = await Item.objects.all()
    if hx_request:
        return templates.TemplateResponse(
            "partials/item_list.html", {"request": request, "items": items}
        )
    return templates.TemplateResponse("items.html", {"request": request, "items": items})

@app.delete("/items/{pk}")
async def delete_item(pk: int):
    await Item.objects.filter(id=pk).delete()
    return Response(status_code=204)
```

---

## Common Patterns Across Backends

### Triggering Client Events from Server

```python
response["HX-Trigger"] = "itemCreated"                    # simple event
response["HX-Trigger"] = '{"itemAdded": {"id": 42}}'     # event with data
```

### Redirect After Mutation

```python
response["HX-Redirect"] = "/items"    # client-side redirect, no swap
```

### Dynamic Swap Override

```python
response["HX-Reswap"] = "none"        # override client hx-swap
response["HX-Retarget"] = "#errors"   # override client hx-target
```
