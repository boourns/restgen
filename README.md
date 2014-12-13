restgen
=======
Code that writes code for writing code.

Generate statically-typed bindings for your REST API in Go.

Currently only implemented enough to generate github.com/boourns/go_shopify.  Not sure what'd be necessary to support more REST APIs.

Basic usage, for example to generate Shopify's API:
```
ruby restgen.rb shopify data/shopify/api.json https://token:secret@shop.myshopify.com/admin
```

That will:
- use `data/shopify/api.json` to determine what actions to add for each type
- fetch an instance of every type
- convert the JSON structure to a go struct
- add the actions supported
- generate types for embedded classes as well (line items, product options, for example)

TODO:
- support child REST objects (`admin/products/X/variants/Y` for example currently does not work)
