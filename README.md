# CouchDB API for Delphi XE2

Delphi-CouchDB is a library that implements the [CouchDB HTTP Document API](http://docs.couchdb.org/en/latest/api/documents.html) and adds a couple of useful features.

Basic functionality:

 * CRUD operations
 * Bulk document saving
 * Large view fetching system (still in progress)

The network requests are send synchronous, for async support the object should be wrapped in a separate thread.

### Installation

The module you need to include is Couch.pas. Depending on whether you have the dependencies installed or not, it might be helpful to add an entry in the Library Path list pointing to the \Vendor folder.

Dependencies:

 * [superobject](https://code.google.com/p/superobject/) for JSON parsing
 * Indy HTTP library
 
### Samples

Here is a quick sample on how to save and retrieve a document.

```delphi
var
  couch: TCouchDB;
  doc: TCouchDBDocument;
begin
  couch := TCouchDB.Create('127.0.0.1', 5984);
  if couch.CreateDatabase('test-db') then begin
    doc := TCouchDBDocument.CreateNew('my-id');
    if couch.SaveDocument<TCouchDBDocument>(doc, 'test-db') then
      try
        doc := couch.GetDocument<TCouchDBDocument>('test-db', 'my-id');
      except
        on ECouchErrorDocNotFound: ShowMessage('Document not found');
      end;
      ShowMessage('Document saved at revision ' + doc._rev);
  end;
end;
```

### Performance

A few interesting benchmarks:

Adding documents in bulk seems to happen faster when you don't supply an id for your documents but let CouchDB assign a UUID. On a test batch of 20000 empty documents, the id ones took 30 seconds on average while the non-id ones only around 6 seconds.

On the other hand, for batches of 500 documents, the performance was very similar for both methods, around 0.15 seconds.

### Tests

The library has been tested with CouchDB 1.3.1. All the test files are in the \Test folder, check them out to see internal workings and expectations of the module. They are also useful as future CouchDB versions will be released.