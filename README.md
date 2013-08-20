# CouchDB API interface implementation for Delphi XE2

Delphi-CouchDB is a library that implements the [CouchDB HTTP Document API](http://docs.couchdb.org/en/latest/api/documents.html) and adds a couple of useful features.

Basic functionality:

 * CRUD operations
 * Bulk document saving
 * Large view fetching system (still in progress)

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
    if couch.SaveDocument<TCouchDBDocument>(doc) then
      try
        doc := couch.GetDocument<TCouchDBDocument>('test-db', 'my-id');
      except
        on ECouchErrorDocNotFound: ShowMessage('Document not found');
      end;
      ShowMessage('Document saved at revision ' + doc._rev);
  end;
end;
```

### Tests

The library has been tested on the CouchDB 1.3.1. All the test files are in the \Test folder, check them out to see if they pass as new versions are released.