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
    http: TIdHTTP;
    serverURL: string;
    function MakeServerRequest(operation: THTTPRequestMethod; url: string;
        postData: string = ''): ISuperObject;
    function StreamToString(aStream: TStream): string;
  public
    constructor Create(serverAddress: string = '127.0.0.1'; serverPort: Integer =
        5984);
    destructor Destroy; override;
    function CreateDatabase(databaseName: string): Boolean;
    function DeleteDatabase(databaseName: string): Boolean;
    function GetDocument<T: TCouchDBDocument>(databaseName, documentId: string): T;

    // TCouchDBDocument -> Boolean
    // takes a document and saves it to the couch
    // if _id field is passed request is routed through PUT
    // otherwise POST is used
    function SaveDocument<T: TCouchDBDocument>(doc: T; databaseName: string):
        Boolean;
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
end;

destructor TCouchDB.Destroy;
begin
  http.Free;
  inherited;
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

function TCouchDB.GetDocument<T>(databaseName, documentId: string): T;
var
  ctx: TSuperRttiContext;
  serverReply: ISuperObject;
begin
  ctx := TSuperRttiContext.Create;
  try
    // make server request
    serverReply := MakeServerRequest(rmGet, databaseName);

    if serverReply.S['error'] <> '' then begin
      raise ECouchErrorDocNotFound.Create('Document not found');
    end;

    Result := ctx.AsType<T>(SO(serverReply));
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

    // remove _id attribute if empty
    if doc._id = '' then begin
      // and send to POST request
      post.Delete('_id');
      serverReply := MakeServerRequest(rmPost, databaseName, post.AsString);
    end else begin
      // id supplied, route to PUT
      serverReply := MakeServerRequest(rmPut, databaseName, post.AsString);
    end;

    Result := serverReply.B['ok'];


    post := nil;
  finally
    ctx.Free;
  end;
  // TODO -cMM: TCouchDB.SaveDocument<T> default body inserted
end;

end.
