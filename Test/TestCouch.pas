unit TestCouch;
{

  Delphi DUnit Test Case
  ----------------------
  This unit contains a skeleton test case class generated by the Test Case Wizard.
  Modify the generated code to correctly setup and call the methods from the unit 
  being tested.

}

interface

uses
  TestFramework, IdHttp, System.Generics.Collections, superobject, Couch,
  System.SysUtils, System.Classes;

type
  // Test methods for class TCouchDB

  TestTCouchDB = class(TTestCase)
  strict private
    FCouchDB: TCouchDB;
    Fctx: TSuperRttiContext;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestAutoFlushBulk;
    procedure TestCreateDatabase;
    procedure TestDeleteDatabase;
    procedure TestFlushBulk;
    procedure TestFlushBulkManyDBs;
    procedure TestGetDocument;
    procedure TestManyInsertsWithIds;
    procedure TestManyInsertsWithoutIds;
    function TestSaveDocument: string;
  end;

implementation

procedure TestTCouchDB.SetUp;
begin
  FCouchDB := TCouchDB.Create;
  Fctx := TSuperRttiContext.Create;

  FCouchDB.CreateDatabase('test');
end;

procedure TestTCouchDB.TearDown;
begin
  FCouchDB.DeleteDatabase('test');
  FCouchDB.DeleteDatabase('test-another');
  FCouchDB.Free;
  FCouchDB := nil;
  Fctx.Free;
end;

procedure TestTCouchDB.TestAutoFlushBulk;
var
  ReturnValue: TCouchDBDocument;
begin
  FCouchDB.useBulkInserts := true;
  FCouchDB.bulkSize := 2;

  // save 2 documents
  FCouchDB.SaveDocument<TCouchDBDocument>(
    TCouchDBDocument.CreateNew('first'), 'test'
  );
  FCouchDB.SaveDocument<TCouchDBDocument>(
    TCouchDBDocument.CreateNew('second'), 'test'
  );

  // expect the second one to be saved
  ReturnValue := TCouchDBDocument.Create;
  try
    ReturnValue := FCouchDB.GetDocument<TCouchDBDocument>('test', 'second');
  except
    // ignore exception, it means the doc doesn't exist
  end;
  Assert(ReturnValue._id = 'second', 'Document not retrieved');
end;

procedure TestTCouchDB.TestCreateDatabase;
var
  ReturnValue: Boolean;
begin
  // first insert should always fail because test is created on setup
  ReturnValue := FCouchDB.CreateDatabase('test');
  Assert(ReturnValue = false, 'Failed to throw error on database present');

  // create another database
  ReturnValue := FCouchDB.CreateDatabase('test-another');
  Assert(ReturnValue = true, 'Failed to create database');

end;

procedure TestTCouchDB.TestDeleteDatabase;
var
  ReturnValue: boolean;
begin
  ReturnValue := FCouchDB.DeleteDatabase('database-should-not-exist');
  Assert(ReturnValue = false, 'Wrong database delation should trigger exception');
end;

procedure TestTCouchDB.TestFlushBulk;
var
  hasPassed: boolean;
  ReturnValue: TCouchDBDocument;
begin
  FCouchDB.useBulkInserts := true;

  // expect first save to do nothing
  hasPassed := false;
  FCouchDB.SaveDocument<TCouchDBDocument>(TCouchDBDocument.CreateNew('first-document'), 'test');
  try
    FCouchDB.GetDocument<TCouchDBDocument>('test', 'first-document');
  except
    on ECouchErrorDocNotFound do begin
      hasPassed := true;
    end;
  end;
  Assert(hasPassed = true, 'Document should not have been written to database');

  // flush bulk and expect to retrieve the document
  FCouchDB.FlushBulk;
  ReturnValue := FCouchDB.GetDocument<TCouchDBDocument>('test', 'first-document');
  Assert(ReturnValue._id = 'first-document', 'Invalid document saved in bulk');
end;

procedure TestTCouchDB.TestFlushBulkManyDBs;
var
  ReturnValue: TCouchDBDocument;
begin
  FCouchDB.useBulkInserts := true;
  FCouchDB.SaveDocument<TCouchDBDocument>(TCouchDBDocument.CreateNew('first'), 'test');

  FCouchDB.CreateDatabase('test-another');
  FCouchDB.SaveDocument<TCouchDBDocument>(TCouchDBDocument.CreateNew('still-first'), 'test-another');

  FCouchDB.FlushBulk;

  ReturnValue := TCouchDBDocument.Create;
  try
    ReturnValue := FCouchDB.GetDocument<TCouchDBDocument>('test', 'first');
    Assert(ReturnValue._id = 'first', 'Document not saved in bulk');
    ReturnValue := FCouchDB.GetDocument<TCouchDBDocument>('test-another', 'still-first');
    Assert(ReturnValue._id = 'still-first', 'Document not saved in bulk');
  except
    // test should fail
  end;
end;

procedure TestTCouchDB.TestGetDocument;
var
  documentId: string;
  databaseName: string;
//  json: ISuperObject;
  testPass: Boolean;
begin
  // expect retrieving a document that doesn't exist to trigger an exception
  // that NEEDS to be handled appropriately on each case
  databaseName := 'this-should-not-exist';
  documentId := '';
  testPass := false;
  try
    FCouchDB.GetDocument<TCouchDBDocument>(databaseName, documentId);
  except
    on ECouchErrorDocNotFound do begin
      testPass := true;
    end;
  end;
  // return value after exception is garbage
//  json := Fctx.AsJson<TCouchDBDocument>(ReturnValue);
  Assert(testPass = true, 'Call to non existent document should return nil');
end;

procedure TestTCouchDB.TestManyInsertsWithIds;
var
  i: Integer;
begin
  FCouchDB.useBulkInserts := true;
  FCouchDB.bulkSize := 2000;
  for i := 1 to FCouchDB.bulkSize do
    FCouchDB.SaveDocument<TCouchDBDocument>(TCouchDBDocument.CreateNew('id-' + IntToStr(i)), 'test');

  Assert(true = true, 'Test only measures execution time');
end;

procedure TestTCouchDB.TestManyInsertsWithoutIds;
var
  i: Integer;
begin
  FCouchDB.useBulkInserts := true;
  FCouchDB.bulkSize := 2000;
  for i := 1 to FCouchDB.bulkSize do
    FCouchDB.SaveDocument<TCouchDBDocument>(TCouchDBDocument.CreateNew, 'test');

  Assert(true = true, 'Test only measures execution time');
end;

function TestTCouchDB.TestSaveDocument: string;
var
  ReturnValue: boolean;
begin
  // expect empty document to be created
  ReturnValue := FCouchDB.SaveDocument<TCouchDBDocument>(TCouchDBDocument.CreateNew, 'test');

  Assert(ReturnValue = true, 'Document save failed');
end;

initialization
  // Register any test cases with the test runner
  RegisterTest(TestTCouchDB.Suite);
end.

