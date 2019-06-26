unit CalendarAPITest;

interface
uses
  DUnitX.TestFramework, iCalendarAPI, System.StrUtils, DateUtils, SysUtils, System.Types, System.Variants;

type

  [TestFixture]
  TCalendardTest = class(TObject)
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure TestTime1;
    [Test]
    procedure TestDate;
    [Test]
    procedure AttendeeExample1;
    [Test]
    procedure ParseLineTest1;
    [Test]
    procedure TestDateTime;
    [Test]
    procedure iCalendarExample1;
    [Test]
    procedure FoldingMethod;
    [Test]
    procedure AttendeeExample2;
    [Test]
    procedure DescriptionExample2;
    [Test]
    procedure DTStampExample1;
    // Sample Methods
    // Simple single Test
    [Test]
    procedure ProdIDExample1;
    [Test]
    procedure OrganizerExample1;
    // Test with TestCase Attribute to supply parameters.
    [Test]
    [TestCase('TestA','1,2')]
    [TestCase('TestB','3,4')]
    procedure Test2(const AValue1 : Integer;const AValue2 : Integer);
  end;

implementation

procedure TCalendardTest.Setup;
begin
end;

procedure TCalendardTest.TearDown;
begin
end;

procedure TCalendardTest.FoldingMethod;
begin
end;

procedure TCalendardTest.iCalendarExample1;
//https://icalendar.org/iCalendar-RFC-5545/4-icalendar-object-examples.html
var
  lText: String;
  Calendar: TCalendar;
begin
  Calendar := TCalendar.Create;
  Calendar.PRODID := '-//xyz Corp//NONSGML PDA Calendar Version 1.0//EN';

  Calendar.VERSION := '2.0';
  lText := Calendar.VERSION;
  Assert.AreEqual('2.0',lText);
  Assert.AreEqual(2,Double(Calendar.VERSION),0.001);

  with Calendar.Event_Add do begin
    (ItemByName['DTSTAMP'] as TItemValue).Text := '19960704T120000Z';
    UID.Value := 'uid1@example.com';
    ORGANIZER.Text:= ':mailto:jsmith@example.com';
    DTSTART_Add.Value := EncodeDateTime(1996,09,18,14,30,00,0);
    DTEND_Add.Value := EncodeDateTime(1996,09,20,22,00,00,0);
    STATUS.Value := 'CONFIRMED';
    CATEGORIES_Add.Value := 'CONFERENCE';
    SUMMARY.Value := 'Networld+Interop Conference';
    DESCRIPTION.Text := 'Networld+Interop Conference'#13#10 +
      '  and Exhibit\nAtlanta World Congress Center\n'#13#10 +
      ' Atlanta\, Georgia';
  end;
  Assert.AreEqual('VCALENDAR',Calendar.Name);
  Assert.AreEqual('VEVENT',Calendar.Events[0].Name);

  lText :=
    'BEGIN:VCALENDAR'#13#10 + //0
    'PRODID:-//xyz Corp//NONSGML PDA Calendar Version 1.0//EN'#13#10 + //1
    'VERSION:2.0'#13#10 + //2
    'BEGIN:VEVENT'#13#10 + //3
    'DTSTAMP:19960704T120000Z'#13#10 + //4
    'UID:uid1@example.com'#13#10 + //5
    'ORGANIZER:mailto:jsmith@example.com'#13#10 + //6
    'DTSTART:19960918T143000Z'#13#10 + //7
    'DTEND:19960920T220000Z'#13#10 + //8
    'STATUS:CONFIRMED'#13#10 + //9
    'CATEGORIES:CONFERENCE'#13#10 + //10
    'SUMMARY:Networld+Interop Conference'#13#10 + //11
    'DESCRIPTION:Networld+Interop Conference'#13#10 + //12
    ' and Exhibit\nAtlanta World Congress Center\n'#13#10 + //13
    'Atlanta\, Georgia'#13#10 + //14
    'END:VEVENT'#13#10 + //15
    'END:VCALENDAR'#13#10 ; //16
  Assert.AreEqual(lText,Calendar.AsText);
end;

procedure TCalendardTest.OrganizerExample1;
var
  Cal: TCalendar;
  Item: TItemValue;
  lText: String;
begin
  Cal:= TCalendar.Create;
  Item := Cal.Event_Add.ORGANIZER;
  Item.Text:= ':mailto:jsmith@example.com';
  lText := Cal.Events[0].ORGANIZER.Value;
  Assert.AreEqual('mailto:jsmith@example.com',lText);
  Cal.Free;
end;

procedure TCalendardTest.DTStampExample1;
var
  Cal: TCalendar;
  Item: TItemValue;
  lText: String;
begin
  Cal:= TCalendar.Create;

  Item := Cal.Event_Add['DTSTAMP'] as TItemValue;
  Item.Text := '19960704T120000Z';
  Assert.IsTrue(VarIsType(Item.Value,varDate));
  Assert.AreEqual(EncodeDateTime(1996,07,04,12,00,00,0),TDateTime(Item.Value));

  Cal.Free;
end;

procedure TCalendardTest.DescriptionExample2;
var
  Cal: TCalendar;
  Item: TItemValue;
  lText: String;
begin
  Cal:= TCalendar.Create;
  Item := Cal.Event_Add.DESCRIPTION;
  Item.Text := 'Networld+Interop Conference'#13#10 +
      '  and Exhibit\nAtlanta World Congress Center\n'#13#10 +
      ' Atlanta\, Georgia';

  lText := Cal.Events[0].DESCRIPTION.Value;
  Assert.AreEqual('Networld+Interop Conference and Exhibit'#13'Atlanta World Congress Center'#13'Atlanta, Georgia', lText);
  Cal.Free;
end;

procedure TCalendardTest.AttendeeExample1;
var
  Cal: TCalendar;
  Item: TItemValue;
  lText: String;
begin
  Cal:= TCalendar.Create;

  Item := Cal.Event_Add.ATTENDEE_Add;
  Item.Text := ';RSVP=TRUE;ROLE=REQ-PARTICIPANT;CUTYPE=GROUP:mailto:employee-A@example.com';
  lText := Item.Text;
  Assert.AreEqual('ATTENDEE;RSVP=TRUE;CUTYPE=GROUP;ROLE=REQ-PARTICIPANT:mailto:employee-A@example.com',lText);
  lText := Cal.AsText;
  Assert.AreEqual(
     'BEGIN:VCALENDAR'#$D#$A
    +'BEGIN:VEVENT'#$D#$A
    +'ATTENDEE;RSVP=TRUE;CUTYPE=GROUP;ROLE=REQ-PARTICIPANT:mailto:employee-A@example.com'#$D#$A
    +'END:VEVENT'#$D#$A
    +'END:VCALENDAR'#$D#$A
  ,lText);
  Cal.Free;
end;

procedure TCalendardTest.AttendeeExample2;
var
  Cal: TCalendar;
  Item: TItemValue;
  lText: String;
begin
  Cal:= TCalendar.Create;
  Cal.AsText :=
    'BEGIN:VCALENDAR'#13#10+
    'BEGIN:VEVENT'#13#10+
    'ORGANIZER;CN=John Smith:MAILTO:jsmith@host.com'#13#10 + //0
    'ATTENDEE;ROLE=REQ-PARTICIPANT;PARTSTAT=TENTATIVE;DELEGATED-FROM='#13#10 + //1
    ' "MAILTO:iamboss@host2.com";CN=Henry Cabot:MAILTO:hcabot@'#13#10 + //2
    ' host2.com'#13#10 + //3
    'ATTENDEE;ROLE=NON-PARTICIPANT;PARTSTAT=DELEGATED;DELEGATED-TO='#13#10 + //4
    ' "MAILTO:hcabot@host2.com";CN=The Big Cheese:MAILTO:iamboss'#13#10 + //5
    ' @host2.com'#13#10 + //6
    'ATTENDEE;ROLE=REQ-PARTICIPANT;PARTSTAT=ACCEPTED;CN=Jane Doe'#13#10 + //7
    ' :MAILTO:jdoe@host1.com'#13#10 + //8
    'END:VEVENT'#13#10+
    'END:VCALENDAR'#13#10;
  Item := Cal.Events[0].ATTENDEE_Add;
  Item.Text := ';RSVP=TRUE;ROLE=REQ-PARTICIPANT;CUTYPE=GROUP:'#13#10+
               ' mailto:employee-A@example.com';
  Assert.IsTrue(VarIsType(Item.Value,varDate));
  Assert.AreEqual(EncodeDateTime(1996,07,04,12,00,00,0),TDateTime(Item.Value));

  Cal.Free;
end;

procedure TCalendardTest.ParseLineTest1;
var
  lText: String;
  lName: String;
  lValue: String;
  lParams: TItemValue.TParamRecDynArray;
begin
  lText := 'ATTENDEE;PARTSTAT=ACCEPTED;PARTSTAT1="DENIED":mailto:jqpublic@example.com';
  Assert.IsTrue(TItemValue._ParseLine(lText,lName,lValue,lParams));
  Assert.AreEqual('ATTENDEE',lName);
  Assert.AreEqual('mailto:jqpublic@example.com',lValue);
  Assert.AreEqual(2,Length(lParams));
  Assert.AreEqual('PARTSTAT',lParams[0].Name);
  Assert.AreEqual('ACCEPTED',lParams[0].Value);
  Assert.AreEqual('PARTSTAT1',lParams[1].Name);
  Assert.AreEqual('DENIED',lParams[1].Value);
end;

procedure TCalendardTest.ProdIDExample1;
var
  Cal: TCalendar;
  Item: TItemValue;
  lText: String;
begin
  Cal:= TCalendar.Create;
  Item := Cal['PRODID'] as TItemValue;
  Item.Text := '-//xyz Corp//NONSGML PDA Calendar Version 1.0//EN';
  lText := Cal.PRODID.Value;
  Assert.AreEqual('-//xyz Corp//NONSGML PDA Calendar Version 1.0//EN',lText);
  Cal.Free;
end;

procedure TCalendardTest.Test2(const AValue1 : Integer;const AValue2 : Integer);
begin
end;

procedure TCalendardTest.TestDateTime;
var
  lDateTime: TDateTime;
  lGMT: Boolean;
  lText: String;
begin
  //DTSTART:19970714T133000            ;Local time
  Assert.IsTrue(TISO8601._StrToDateTime('19970714T133000',lDateTime,lGMT));
  lText := varToStr(lDateTime);
  Assert.IsFalse(lGMT);
  Assert.AreEqual('7/14/1997 1:30:00 PM',lText);
//  DTSTART:19970714T173000Z           ;UTC time
  Assert.IsTrue(TISO8601._StrToDateTime('19970714T173000Z',lDateTime,lGMT));
  lText := varToStr(lDateTime);
  Assert.IsTrue(lGMT);
  Assert.AreEqual('7/14/1997 5:30:00 PM',lText);
//  DTSTART;TZID=US-Eastern:19970714T133000    ;Local time and time
  Assert.IsTrue(TISO8601._StrToDateTime('19970714T133000',lDateTime,lGMT));
  lText := varToStr(lDateTime);
  Assert.IsFalse(lGMT);
  Assert.AreEqual('7/14/1997 1:30:00 PM',lText);
end;

procedure TCalendardTest.TestDate;
var
  lDateTime: TDateTime;
  lGMT: Boolean;
  lText: String;
begin
  //DTSTART:19970714 ;Local time
  Assert.IsTrue(TISO8601._StrToDateTime('19970714',lDateTime,lGMT));
  Assert.IsFalse(lGMT);
  lText := varToStr(lDateTime);
  Assert.AreEqual('7/14/1997',lText);
end;

procedure TCalendardTest.TestTime1;
var
  lValue: Variant;
  lText: String;
  lDateTime: TDateTime;
  lGMT: Boolean;
begin
//  X-TIMEOFDAY:083000
  Assert.IsTrue(TISO8601._StrToDateTime('083000',lDateTime,lGMT));
  Assert.IsFalse(lGMT);
  lText := varToStr(lDateTime);
  Assert.AreEqual('8:30:00 AM',lText);

//  X-TIMEOFDAY:133000Z
  Assert.IsTrue(TISO8601._StrToDateTime('133000Z',lDateTime,lGMT));
  Assert.IsTrue(lGMT);
  lText := varToStr(lDateTime);
  Assert.AreEqual('1:30:00 PM',lText);

//  X-TIMEOFDAY;TZID=US-Eastern:083000
  Assert.IsTrue(TISO8601._StrToDateTime('083000',lDateTime,lGMT));
  Assert.IsFalse(lGMT);
  lText := varToStr(lDateTime);
  Assert.AreEqual('8:30:00 AM',lText);
end;

initialization
  TDUnitX.RegisterTestFixture(TCalendardTest);
end.

