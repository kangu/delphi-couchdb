unit Couch;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, superobject, IdHttp, IdURI;

type
  THTTPRequestMethod = (rmGet, rmPost, rmDelete, rmPut);

  ECouchErrorDocNotFound = class(Exception);

  TCouchDBDocument = class(TPersistent)
  public
    _id, _rev: string;
    constructor CreateNew(setId: string = ''); virtual;
  end;

  TCouchDBError = class(TCouchDBDocument)
  public
    error: string;
  end;

  TSampleDoc = class(TCouchDBDocument)
  public
    extraParam: string;
  end;

  TCouchDB = class(TObject)
  private
    iUseBulkInserts: Boolean;
    FbulkDBNames: TStringList;
    FbulkData: TStringList;
    FbulkSize: Integer;
    // keeps track of the number of documents in the bulk queue
    // independent of target database
    FbulkCount: integer;
    http: TIdHTTP;
    serverURL: string;

    // String, String -> Boolean
    // matches the saveDocument structure but adds to the document to the bulk queue
    //
    // expect new database entry created to return true
    // expect existing database entry used to return false
    function AppendToBulk(databaseName, document: string): Boolean;
    function MakeServerRequest(operation: THTTPRequestMethod; url: string;
        postData: string = ''): ISuperObject;
    function StreamToString(aStream: TStream): string;
  public
    constructor Create(serverAddress: string = '127.0.0.1'; serverPort: Integer =
        5984);
    destructor Destroy; override;
    function CreateDatabase(databaseName: string): Boolean;
    function DeleteDatabase(databaseName: string): Boolean;

    // flushes all database queues to couch
    function FlushBulk: Boolean;

    // String -> JSON
    // retrieves list of id-key value for all documents in provided database
    function GetAllDocs(databaseName: string): ISuperObject;

    // String, String -> TCouchDBDocument
    // retrieves given document id from database
    //
    // expect exception to be returned if document doesn't exist
    function GetDocument<T: TCouchDBDocument>(databaseName, documentId: string): T;

    // TCouchDBDocument -> Boolean
    // takes a document and saves it to the couch
    // if _id field is passed request is routed through PUT
    // otherwise POST is used
    function SaveDocument<T: TCouchDBDocument>(doc: T; databaseName: string):
        Boolean;

    property bulkSize: Integer read FbulkSize write FbulkSize;
    // allow component to cache insert requests grouped by database name
    // documents are flushed to the database by using FlushBulk
    property useBulkInserts: Boolean read iUseBulkInserts write iUseBulkInserts;
  published
  end;

implementation

constructor TCouchDBDocument.CreateNew(setId: string = '');
begin
  _id := setId;
end;

constructor TCouchDB.Create(serverAddress: string = '127.0.0.1'; serverPort:
    Integer = 5984);
begin
  http := TIdHTTP.Create(nil);
  serverURL := Format('http://%s:%d/', [serverAddress, serverPort]);

  // initialize bulk insert feature
  iUseBulkInserts := false;
  bulkSize := 2000; // seems to be the ideal size for a set of empty documents
  FbulkCount := 0;
  // each pair of dbname -> data will be synced by using the stringlist id
  FbulkDBNames := TStringList.Create;
  FbulkData := TStringList.Create;
end;

destructor TCouchDB.Destroy;
begin
  http.Free;
  FbulkDBNames.Free;
  FbulkData.Free;
  inherited;
end;

function TCouchDB.AppendToBulk(databaseName, document: string): Boolean;
var
  index: integer;
begin
  index := FbulkDBNames.IndexOf(databaseName);
  if index = -1 then begin
    FbulkDBNames.Add(databaseName);
    index := FbulkDBNames.Count - 1;

    FbulkData.Add('');  // empty to start with
  end;

  if Length(FbulkData[index]) = 0 then
    FbulkData[index] := document
  else
    FbulkData[index] := FbulkData[index] + ',' + document;

  Inc(FbulkCount);
  if FbulkCount >= FbulkSize then begin
    FlushBulk;
  end;
end;

function TCouchDB.CreateDatabase(databaseName: string): Boolean;
var
  json: ISuperObject;
begin
  Result := false;
  json := MakeServerRequest(rmPut, databaseName);

  Result := json.B['ok'];
end;

function TCouchDB.DeleteDatabase(databaseName: string): Boolean;
var
  json: ISuperObject;
begin
  Result := false;
  json := MakeServerRequest(rmDelete, databaseName);

  if json.S['error'] = '' then
    Result := json.B['ok'];
end;

function TCouchDB.FlushBulk: Boolean;
var
  i: integer;
  serverReply: ISuperObject;
begin
  for i := 0 to FbulkDBNames.Count - 1 do begin
    serverReply := MakeServerRequest(rmPost, FbulkDBNames[i] + '/_bulk_docs',
      Format('{"docs":[%s]}', [FbulkData[i]]));

    // TODO maybe should parse the results for errors?
    // doesn't make sense for very large arrays 1000+
    // would be nice to be optional
    Result := serverReply.IsType(stArray);
  end;
  FbulkDBNames.Clear;
  FbulkData.Clear;

  FbulkCount := 0;
end;

function TCouchDB.GetAllDocs(databaseName: string): ISuperObject;
var
  ctx: TSuperRttiContext;
  serverReply: ISuperObject;
begin
  ctx := TSuperRttiContext.Create;
  try
    serverReply := MakeServerRequest(rmGet, databaseName + '/_all_docs');
    Result := serverReply.O['rows'];
  finally
    ctx.Free;
  end;
end;

function TCouchDB.GetDocument<T>(databaseName, documentId: string): T;
var
  ctx: TSuperRttiContext;
  serverReply: ISuperObject;
begin
  ctx := TSuperRttiContext.Create;
  try
    // make server request
    serverReply := MakeServerRequest(rmGet, databaseName + '/' + documentId);

    if serverReply.S['error'] <> '' then begin
      raise ECouchErrorDocNotFound.Create('Document not found');
    end;

    Result := ctx.AsType<T>(serverReply);
  finally
    ctx.Free;
  end;
end;

function TCouchDB.StreamToString(aStream: TStream): string;
var
  SS: TStringStream;
begin
  if aStream <> nil then
  begin
    SS := TStringStream.Create('');
    try
      SS.CopyFrom(aStream, 0);  // No need to position at 0 nor provide size
      Result := SS.DataString;
    finally
      SS.Free;
    end;
  end else
  begin
    Result := '';
  end;
end;

function TCouchDB.MakeServerRequest(operation: THTTPRequestMethod; url: string;
    postData: string = ''): ISuperObject;
var
  ms, postStream: TMemoryStream;
begin
  Result := SO;
  http.Request.ContentType := 'application/json';

  ms := TMemoryStream.Create;
  postStream := TStringStream.Create(postData);
  try
    case operation of
      rmGet: begin
        try
          http.Get(TIdURI.URLEncode(serverURL + url), ms);
          Result := SO(StreamToString(ms));
        except
          on E: EIdHTTPProtocolException do begin
            case E.ErrorCode of
              404: begin
                // just return nothing if document is not found
                Result := SO('{ "error": "not_found" }');
              end;
              else  // raise error to catch problems early on
                raise;
            end;
          end;
          else  // make sure to raise other unknown errors to catch them
            raise;
        end;
      end;
      rmPost: begin
        try
          // TODO logic here should be included to handle batch requests
          http.Post(TIdURI.URLEncode(serverURL + url), postStream, ms);
          Result := SO(StreamToString(ms));
        except
          raise;
        end;
      end;
      rmPut: begin
        try
          http.Put(TIdURI.URLEncode(serverURL + url), postStream, ms);
          Result := SO(StreamToString(ms));
        except
          on E: EIdHTTPProtocolException do begin
            case E.ErrorCode of
              412: begin
                // just return nothing if document is not found
                Result := SO('{ "error": "revision_conflict" }');
              end;
              else  // raise error to catch problems early on
                raise;
            end;
          end;
          else  // make sure to raise other unknown errors to catch them
            raise;
        end;
      end;
      rmDelete: begin
        try
          http.Delete(TIdURI.URLEncode(serverURL + url));
          Result := SO(StreamToString(ms));
        except
          on E: EIdHTTPProtocolException do begin
            case E.ErrorCode of
              404: begin
                // just return nothing if document is not found
                Result := SO('{ "error": "not_found" }');
              end;
              else  // raise error to catch problems early on
                raise;
            end;
          end;
        end;
      end;
    end;
  finally
    ms.Free;
    postStream.Free;
  end;
end;

function TCouchDB.SaveDocument<T>(doc: T; databaseName: string): Boolean;
var
  ctx: TSuperRttiContext;
  serverReply: ISuperObject;
  post: ISuperObject;
begin
  Result := false;

  ctx := TSuperRttiContext.Create;
  try
    post := ctx.AsJson<TCouchDBDocument>(doc);

    // also remove _rev if empty
    if doc._rev = '' then
      post.Delete('_rev');

    // if bulk insert is set, document is routed to the internal storage
    if iUseBulkInserts then begin
      if doc._id = '' then
        post.Delete('_id');
      AppendToBulk(databaseName, post.AsString);
    end else begin
      // go ahead and run http request
      // remove _id attribute if empty
      if doc._id = '' then begin
        // and send to POST request
        post.Delete('_id');
        serverReply := MakeServerRequest(rmPost, databaseName, post.AsString);
      end else begin
        // id supplied, route to PUT
        serverReply := MakeServerRequest(rmPut, databaseName + '/' + doc._id, post.AsString);
      end;

      Result := serverReply.B['ok'];
    end;


    post := nil;
  finally
    ctx.Free;
  end;
  // TODO -cMM: TCouchDB.SaveDocument<T> default body inserted
end;

end.
