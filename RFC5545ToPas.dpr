program RFC5545ToPas;
{$SCOPEDENUMS ON}
{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  IdHTTP,
  IdSSLOpenSSL,
  System.Classes,
  System.Net.URLClient,
  IoUTIls,
  System.Types,
  System.SysConst,
  System.Character,
  System.Generics.Collections,
  TypInfo,
  Xml.XMLDoc,
  Xml.XMLIntf,
  Xml.xmldom,
  Xml.omnixmldom,
  System.JSON,
  System.JSON.Serializers,
  Xml.Internal.OmniXML,
  Winapi.ShellAPI,
  Winapi.Messages,
  Winapi.Windows,
  System.StrUtils;

type
  TStringDynArray_Helper = record helper for TStringDynArray
  private
    function GetCount: Integer;
    function Join(const Delim: String = ','): string;
    procedure SetCount(const Value: Integer);
  public
    function Add: Integer; overload;
    function Add(const aValue: String): Integer; overload;
    function Add(const aValue: String; const aArgs: array of const): Integer; overload;
    function Add(const aValues: TStringDynArray): Integer; overload;
    function AddUnique(const aValue: String): Boolean;
    procedure Insert(aIndex: Integer; const aValue: String);
    procedure Delete(aIndex: Integer; Count: Integer = 1);
    function Contains(const aValue: String; IgnoreCase: Boolean = True): Boolean;
    function IndexOf(const aValue: String; IgnoreCase: Boolean = True): Integer;
    procedure Trim;
    procedure LoadFromFile(const FileName: String);
    procedure SaveToFile(const FileName: String);
    property Count: Integer read GetCount write SetCount;
  end;
  TNameAnd<T> = record
  public
    Name: string;
    [JsonIgnore]
    Item: T;
    constructor Create(const aName: String);
  end;

  TDynArray_<T> = record
  public
    type
      P = ^T;
      TEnumorator = record
        Items: array of T;
        CurrentIndex: Integer;
        function MoveNext: Boolean; inline;
        function GetCurrent: T; inline;
        property Current: T read GetCurrent;
      end;
  private
    function GetCount: Integer; inline;
    function GetVar(Index: Integer): P; inline;
    procedure SetCount(const Value: Integer); inline;
    function GetItem(Index: Integer): T; inline;
    procedure SetItem(Index: Integer; const Value: T);
  public
    Items: array of T;
    function GetEnumerator: TEnumorator;
    function Add(const aValue: T): Integer;
    procedure Insert(Index: Integer; const aValue: T);
    property Count: Integer read GetCount write SetCount;
    property &Var[Index: Integer]: P read GetVar;
    property Item[Index: Integer]: T read GetItem write SetItem;
  end;



  TOccurance = (
    REQUIRED,
    OPTIONAL,
    MUST_NOT_occur_more_than_once,
    SHOULD_NOT_occur_more_than_once,
    MAY_occur_more_than_once);
  TOccurance_Helper = record helper for TOccurance
  public
    function TryParse(const aValue: String): Boolean;
    function ToString: String;
  end;
  TOccurances = set of TOccurance;
  TOccurances_Helper = record helper for TOccurances
  public
    class function Contains(const aValue: String): TOccurances; static;
  end;
  TParameter = class
  public
    type
      TField = (Name,Parameter_Name,Purpose,Format_Definition,Description,Example,Following_Notation);
      TField_Helper = record helper for TField
      public
        function TryParse(const aValue: String): Boolean;
        function ToString: String;
      end;
      TList = TObjectList<TParameter>;
  private
    FSections: array[TField] of TStringDynArray;
  public
    Lines: TStringDynArray;
    constructor Create(const aLines: TStringDynArray);
    procedure AddComment(const Indent: String; var Lines: TStringDynArray);
    function XMLDocs: IXMLDocument;
    function ParamName: String;
    property Name: TStringDynArray index TField.Name read FSections[TField.Name];
    property Parameter_Name: TStringDynArray index TField.Parameter_Name read FSections[TField.Parameter_Name];
    property Purpose: TStringDynArray index TField.Purpose read FSections[TField.Purpose];
    property Format_Definition: TStringDynArray index TField.Format_Definition read FSections[TField.Format_Definition];
    property Description: TStringDynArray index TField.Description read FSections[TField.Description];
    property Example: TStringDynArray index TField.Example read FSections[TField.Example];
    property Following_Notation: TStringDynArray index TField.Following_Notation read FSections[TField.Following_Notation];
  end;

  TType = class
  public
    type
      TList = class(TObjectDictionary<string,TType>)
      public
        type
          TPair = TPair<string,TType>;
      public
        procedure Add(Item: TType);
        function ValueNameTo(const aName: String): TDynArray_<TType>;
      end;
      TField = (Name,Value_Name,Purpose,Format_Definition,Value_Type,Description,Example);
      TField_Helper = record helper for TField
      public
        function ToString: String;
        function TryParse(const aValue: String): Boolean;
      end;
      TNameAnd = TNameAnd<TType>;
      TDefination = record
        Name: String;
        Lines: TStringDynArray;
      end;

  private
    FSections: array[TField] of TStringDynArray;
    FDefinations: TDynArray_<TDefination>;
  public
    Lines: TStringDynArray;
    constructor Create(const aLines: TStringDynArray);
    class procedure AddXMLDoc_Returns(const Types: array of TType; const Indent: String; var Lines: TStringDynArray);
    procedure Parse;
    function TypeName: String;
    property Name: TStringDynArray index TField.Name read FSections[TField.Name];
    property Value_Name: TStringDynArray index TField.Value_Name read FSections[TField.Value_Name];
    property Purpose: TStringDynArray index TField.Purpose read FSections[TField.Purpose];
    property Format_Definition: TStringDynArray index TField.Format_Definition read FSections[TField.Format_Definition];
    property Value_Type: TStringDynArray index TField.Value_Type read FSections[TField.Value_Type];
    property Description: TStringDynArray index TField.Description read FSections[TField.Description];
    property Example: TStringDynArray index TField.Example read FSections[TField.Example];
  end;

  TProperty = class
  public
    type
      TDynArray = array of TProperty; // for reference
      TField = (Name,Property_Name,Purpose,Value_Type,Property_Parameters,Conformance,Description,Format_Definition,Example);
      TField_Helper = record helper for TField
      public
        function TryParse(const aValue: String): Boolean;
        function ToString: String;
      end;
      TInstanceType = (Single,Multiple);
      TInstanceTypes = set of TInstanceType;
      TList = TObjectList<TProperty>;
      TParam = record
      public
        type
           TDynArray = array of TParam;
      public
        Occurances: TOccurances;
        Name: String;
        Parameter: TParameter;
        constructor Create(const aOccurances: TOccurances; const aName: String; aParameter: TParameter = nil);
        class function FixName(const aName: String): String; static;
        class procedure TryAdd(var Params: TParam.TDynArray; Text: String; Occurances: TOccurances); static;
      end;
  private
    FSections: array[TField] of TStringDynArray;
  public
    InstanceTypes: TInstanceTypes;
    Parameters: TParam.TDynArray;
    Lines: TStringDynArray;
    [JSONIgnore]
    &Type: TDynArray_<TType>;
    constructor Create(const aLines: TStringDynArray);
    procedure AddXMLDoc_Summary(const Indent: String; var Lines: TStringDynArray);
    procedure Parse;
    function PropName: String;
    function ObjType: String;
    function XMLDocs: IXMLDocument;
    property Name: TStringDynArray index TField.Name read FSections[TField.Name];
    property Property_Name: TStringDynArray index TField.Property_Name read FSections[TField.Property_Name];
    property Purpose: TStringDynArray index TField.Purpose read FSections[TField.Purpose];
    property Value_Type: TStringDynArray index TField.Value_Type read FSections[TField.Value_Type];
    property Property_Parameters: TStringDynArray index TField.Property_Parameters read FSections[TField.Property_Parameters];
    property Conformance: TStringDynArray index TField.Conformance read FSections[TField.Conformance];
    property Description: TStringDynArray index TField.Description read FSections[TField.Description];
    property Format_Definition: TStringDynArray index TField.Format_Definition read FSections[TField.Format_Definition];
    property Example: TStringDynArray index TField.Example read FSections[TField.Example];
  end;
//  [JsonSerialize(TJsonMemberSerialization.Public)]
  TComponent = class
  public
    type
      TField = (Name, Component_Name, Purpose, Format_Definition, Description, Example, Note);
//      TField = (ICalBody,CalProps,Component,IANA_Comp,X_Comp,Eventc,EventProp);
      TField_Helper = record helper for TField
      public
        function TryParse(const aValue: String): Boolean;
        function ToString: String;
      end;
      TNameProp = record
        Name: String;
        &Property: TProperty;
        constructor Create(const aName: String; aProperty: TProperty = nil);
      end;
      TProp = record
      public
        Occurances: TOccurances;
        Comments: String;
        NameProps: array of TNameProp;
        class function FixName(const aName: String): String; static;
        procedure AppendComment(const Line: String);
        procedure AppendItems(const Items: TArray<String>);
      end;
      TPropDynArray = array of TProp;
      TPropDynArray_Helper = record helper for TPropDynArray
      private
        function GetCount: Integer; inline;
        procedure SetCount(const Value: Integer); inline;
      public
        property Count: Integer read GetCount write SetCount;
      end;
      TComp = TNameAnd<TComponent>;
      TCompDynArray = array of TComp;

      TDefination = record
        Name: String;
        Lines: TStringDynArray;
        Props: TPropDynArray;
        Comps: TCompDynArray;
        procedure Parse_Prop;
        procedure Parse;
        procedure Parse_Comp;
      end;

      TDefinationDynArray = array of TDefination;
      TDefination_Helper = record helper for TDefinationDynArray
      private
        function GetCount: Integer; inline;
        procedure SetCount(const Value: Integer); inline;
      public
        constructor Create(const Lines: TStringDynArray);
        property Count: Integer read GetCount write SetCount;
      end;

      TList = TObjectList<TComponent>;
  private
    FSections: array[TField] of TStringDynArray;
  public
    Definations: TDefinationDynArray;
    Lines: TStringDynArray;
    constructor Create(const aLines: TStringDynArray);
    function IsComponentName(const aName: String): Boolean;
    function Props: TPropDynArray;
    function Comps: TCompDynArray;
    function XMLDocs: IXMLDocument;
    function CompName: String;
    property Name: TStringDynArray index TField.Name read FSections[TField.Name];
    property Component_Name: TStringDynArray index TField.Component_Name read FSections[TField.Component_Name];
    property Purpose: TStringDynArray index TField.Purpose read FSections[TField.Purpose];
    property Format_Definition: TStringDynArray index TField.Format_Definition read FSections[TField.Format_Definition];
    property Description: TStringDynArray index TField.Description read FSections[TField.Description];
    property Example: TStringDynArray index TField.Example read FSections[TField.Example];
    property Note: TStringDynArray index TField.Note read FSections[TField.Note];
  end;


  TProcessSection = reference to procedure(const Lines: TStringDynArray);

  TRFC5545 = class
  public
    [JSONIgnore]
    Doc: TStringList;
    Parameters: TParameter.TList;
    Properties: TProperty.TList;
    Components: TComponent.TList;
    Types: TType.TList;
    constructor Create(const URL: String = 'https://tools.ietf.org/rfc/rfc5545.txt');
    destructor Destroy; override;
    procedure AddBaseComponentIntf(var Result: TStringDynArray; var Types: TStringDynArray);
    procedure AddBaseComponentImp(var Result: TStringDynArray; const Types: TStringDynArray);
    procedure AddBaseValueIntf(var Result: TStringDynArray; var Types: TStringDynArray);
    procedure AddBaseValueImp(var Result: TStringDynArray);
    procedure AddCommonConsts(var Result: TStringDynArray);
    procedure AddCommonIntf(var Result: TStringDynArray);
    procedure AddCommonImp(var Result: TStringDynArray);
    procedure AddComponentIntf(var Result: TStringDynArray; const Component: TComponent);
    procedure AddComponentImp(var Result: TStringDynArray; const Component: TComponent);
    procedure Load(const URL: string);
    procedure Parse;
    procedure RemovePageBreaks;
    procedure DoSections(const SectionPrefix: String; ProcessSection: TProcessSection);
    procedure ProcessParam(const Lines: TStringDynArray);
    procedure ProcessTypes(const Lines: TStringDynArray);
    procedure ProcessProperties(const Lines: TStringDynArray);
    procedure ProcessComponent(const Lines: TStringDynArray); overload;
    procedure AddEnumHelperIntf(const Indent, TypeName: String; var Lines: TStringDynArray);
    procedure AddEnumHelperImp(const TypeName: String; var Lines: TStringDynArray; Space: Char = '-');
    function GetMethodIntf(const Indent: String; aType,aIndexType: String): String;
    function GetMethodImp(aClass,aType,aIndexType: String): TStringDynArray;
    function GenerateDelphi(const UnitName: string): TStringDynArray;
    procedure Process;
    procedure ChangeProperty(aPropName: String; const Proc: TProc<TProperty>);
    function GetParameter(aParamName: String): TParameter;
    procedure ProcessComponentProp(var aProp: TComponent.TProp);
    procedure ProcessComponentSubs(aComp: TComponent);
    procedure ProcessPropertyParam(var aParam: TProperty.TParam);
  end;



{ TRFC5545 }

constructor TRFC5545.Create(const URL: String = 'https://tools.ietf.org/rfc/rfc5545.txt');
begin
  inherited Create;
  Doc := TStringList.Create;
  Parameters := TParameter.TList.Create;
  Properties := TProperty.TList.Create;
  Components := TComponent.TList.Create;
  Types := TType.TList.Create;
  Load(URL);
  Parse;
end;

destructor TRFC5545.Destroy;
begin
  FreeAndNil(Types);
  FreeAndNil(Components);
  FreeAndNil(Properties);
  FreeAndNil(Parameters);
  FreeAndNil(Doc);
  inherited;
end;

procedure TRFC5545.AddBaseComponentIntf(var Result: TStringDynArray; var Types: TStringDynArray);
var
  &Property: TProperty;
  lType: String;
  Comma: String;
begin
  Result.Add('  TBaseComponent = class');
  Result.Add('  public');
  Result.Add('  type');
  Result.Add('    TProperty = (');
  Comma := ' ';
  for &Property in Properties do begin
    Result.Add('        %s%s',[Comma,&Property.PropName.Replace('-','_')]);
    Comma := ',';
  end;
  Result.Add('      );');
  AddEnumHelperIntf('    ','TProperty',Result);

  Result.Add('  private');
  Result.Add('    function GetAsText: String;');
  Result.Add('    procedure SetAsText(const Value: String);');
  Result.Add('    function GetItemByName(const aName: String): TObject;');
  Result.Add('  protected');
  Result.Add('    FProperties: array[TProperty] of TObject;');
  Result.Add('    FItems: TObjectList<TObject>;');
  Result.Add('    class function _DefaultName: String; virtual;');
  Result.Add('    function GetValue(Index: TProperty): Variant;');
  Result.Add('    procedure SetValue(Index: TProperty; const aValue: Variant);');
  Result.Add('    function GetValues(ValueIndex: Integer; Index: TProperty): Variant;');
  Result.Add('    procedure SetValues(ValueIndex: Integer; Index: TProperty; const aValue: Variant);');
  Result.Add('    function NewItem_<T: TItemValue>(const aName: String; const aValue: Variant): T;');
  Result.Add('    function NewItem(Index: TProperty; const aValue: Variant): TItemValue;');
  Result.Add('    function NewItemValue(Index: TProperty): TItemValue;');
  Result.Add('    function GetNameValue(const aName: String; Index: TProperty): Variant;');
  Result.Add('    procedure SetNameValue(const aName: String; Index: TProperty; const aValue: Variant);');
  Result.Add('    function GetItemValue(Index: TProperty): TItemValue;');
  Result.Add('    function GetItemValues(ValueIndex: Integer; Index: TProperty): TItemValue;');
  Result.Add('    function GetValuesCount(Index: TProperty): Integer;');
  Result.Add('    procedure SetValuesCount(Index: TProperty; aValue: Integer);');
  Result.Add('    procedure Build(Builder: TStringBuilder);');
  Result.Add('    property X_[const aName: String]: Variant index TBaseComponent.TProperty.X_ read GetNameValue write SetNameValue;');
  Result.Add('    property X__[Index: Integer]: TItemValue index TBaseComponent.TProperty.X_ read GetItemValues;');
  Result.Add('    property X_Count: Integer index TBaseComponent.TProperty.X_ read GetValuesCount write SetValuesCount;');
  Result.Add('    property IANA_[const aName: String]: Variant index TBaseComponent.TProperty.X_ read GetNameValue write SetNameValue;');
  Result.Add('    property IANA__[Index: Integer]: TItemValue index TBaseComponent.TProperty.IANA_ read GetItemValues;');
  Result.Add('    property IANA_Count: Integer index TBaseComponent.TProperty.IANA_ read GetValuesCount write SetValuesCount;');
  Result.Add('  public');
  Result.Add('    Name: String;');
  Result.Add('    constructor Create;');
  Result.Add('    destructor Destroy; override;');
  Result.Add('    property ItemByName[const Name: String]: TObject read GetItemByName; default;');
  Result.Add('    property AsText: String read GetAsText write SetAsText;');
  Result.Add('  end;');
  Result.Add;
end;

procedure TRFC5545.AddBaseComponentImp(var Result: TStringDynArray; const Types: TStringDynArray);
var
  lType: String;
begin
  Result.Add;
  Result.Add('{ TBaseComponent }');

  Result.Add;
  Result.Add('constructor TBaseComponent.Create;');
  Result.Add('begin');
  Result.Add('  inherited;');
  Result.Add('  Name := _DefaultName;');
  Result.Add('  FItems := TObjectList<TObject>.Create;');
  Result.Add('end;');

  Result.Add;
  Result.Add('destructor TBaseComponent.Destroy;');
  Result.Add('begin');
  Result.Add('  FreeAndNil(FItems);');
  Result.Add('  inherited;');
  Result.Add('end;');

  Result.Add;
  Result.Add('function TBaseComponent.GetAsText: String;');
  Result.Add('begin');
  Result.Add('  Result := TStringBuilder._Build(Build);');
  Result.Add('end;');

  Result.Add;
  Result.Add('class function TBaseComponent._DefaultName: String;');
  Result.Add('begin');
  Result.Add('  Result := '''';');
  Result.Add('end;');

  Result.Add;
  Result.Add('function TBaseComponent.GetValue(Index: TProperty): Variant;');
  Result.Add('begin');
  Result.Add('  if not Assigned(FProperties[Index]) then exit(Unassigned);');
  Result.Add('  Result := (FProperties[Index] as TItemValue).Value;');
  Result.Add('end;');
  Result.Add('function TBaseComponent.GetValues(ValueIndex: Integer; Index: TProperty): Variant;');
  Result.Add('begin');
  Result.Add('  if not Assigned(FProperties[Index]) then Exit(Unassigned);');
  Result.Add('  Result := (FProperties[Index] as TItemValue.TList)[ValueIndex].Value;');
  Result.Add('end;');

  Result.Add;
  Result.Add('function TBaseComponent.GetItemValue(Index: TProperty): TItemValue;');
  Result.Add('begin');
  Result.Add(  'raise Exception.Create(''Error Message'');');
  Result.Add('end;');

  Result.Add;
  Result.Add('function TBaseComponent.GetItemValues(ValueIndex: Integer; Index: TProperty): TItemValue;');
  Result.Add('begin');
  Result.Add(  'raise Exception.Create(''Error Message'');');
  Result.Add('end;');

  Result.Add;
  Result.Add('function TBaseComponent.GetNameValue(const aName: String; Index: TProperty): Variant;');
  Result.Add('begin');
  Result.Add(  'raise Exception.Create(''Error Message'');');
  Result.Add('end;');

  Result.Add;
  Result.Add('function TBaseComponent.GetValuesCount(Index: TProperty): Integer;');
  Result.Add('begin');
  Result.Add(  'raise Exception.Create(''Error Message'');');
  Result.Add('end;');

  Result.Add;
  Result.Add('function TBaseComponent.NewItem(Index: TProperty; const aValue: Variant): TItemValue;');
  Result.Add('begin');
  Result.Add('  // This is where variations of TItemValue can be created');
  Result.Add('  Result := NewItem_<TItemValue>(Index.ToString,aValue);');
  Result.Add('end;');

  Result.Add;
  Result.Add('function TBaseComponent.NewItemValue(Index: TProperty): TItemValue;');
  Result.Add('begin');
  Result.Add('  if not Assigned(FProperties[Index]) then');
  Result.Add('    FProperties[Index] := TItemValue.TList.Create;');
  Result.Add('  Result := NewItem(Index, Unassigned);');
  Result.Add('end;');

  Result.Add;
  Result.Add('function TBaseComponent.NewItem_<T>(const aName: String; const aValue: Variant): T;');
  Result.Add('var');
  Result.Add('  lClass: TItemValue.TClassOf;');
  Result.Add('begin');
  Result.Add('  lClass := T;');
  Result.Add('  Result := lClass.Create(aName,aValue) as T;');
  Result.Add('  FItems.Add(Result);');
  Result.Add('end;');

  Result.Add;
  Result.Add('procedure TBaseComponent.SetNameValue(const aName: String; Index: TProperty; const aValue: Variant);');
  Result.Add('begin');
  Result.Add('  raise Exception.Create(''Error Message'');');
  Result.Add('end;');

  Result.Add;
  Result.Add('procedure TBaseComponent.SetValue(Index: TProperty; const aValue: Variant);');
  Result.Add('begin');
  Result.Add('  if Assigned(FProperties[Index]) then');
  Result.Add('    (FProperties[Index] as TItemValue).Value := aValue');
  Result.Add('  else');
  Result.Add('    FProperties[Index] := NewItem(Index,aValue)');
  Result.Add('end;');

  Result.Add;
  Result.Add('procedure TBaseComponent.SetValues(ValueIndex: Integer; Index: TProperty; const aValue: Variant);');
  Result.Add('begin');
  Result.Add('  if not Assigned(FProperties[Index]) then');
  Result.Add('    FProperties[Index] := TItemValue.TList.Create;');
  Result.Add('  with (FProperties[Index] as TItemValue.TList) do begin');
  Result.Add('    if ValueIndex >= Count then');
  Result.Add('      Count := ValueIndex + 1;');
  Result.Add('    if not Assigned(Items[ValueIndex]) then');
  Result.Add('      Items[ValueIndex] := NewItem(Index,aValue)');
  Result.Add('    else');
  Result.Add('      Items[ValueIndex].Value := aValue;');
  Result.Add('  end;');
  Result.Add('end;');

  Result.Add;
  Result.Add('procedure TBaseComponent.SetValuesCount(Index: TProperty; aValue: Integer);');
  Result.Add('begin');
  Result.Add('  raise Exception.Create(''Error Message'');');
  Result.Add('end;');
  Result.Add;
  Result.Add('procedure TBaseComponent.Build(Builder: TStringBuilder);');
  Result.Add('var');
  Result.Add('  Item: TObject;');
  Result.Add('begin');
  Result.Add('  Builder.AppendFormat(''BEGIN:%s'',[Name]).AppendLine;');
  Result.Add('  for Item in FItems do begin');
  Result.Add('    if Item is TItemValue then begin');
  Result.Add('      TItemValue(Item).Build(Builder);');
  Result.Add('      Builder.AppendLine;');
  Result.Add('    end');
  Result.Add('    else if Item is TItemValue then');
  Result.Add('      TItemValue.TList(Item).Build(Builder)');
  Result.Add('    else if Item is TBaseComponent then');
  Result.Add('      TBaseComponent(Item).Build(Builder);');
  Result.Add('  end;');
  Result.Add('  Builder.AppendFormat(''END:%s'',[Name]).AppendLine;');
  Result.Add('end;');

  Result.Add;
  Result.Add('function TBaseComponent.GetItemByName(const aName: String): TObject;');
  Result.Add('var');
  Result.Add('  Item: TObject;');
  Result.Add('  Index: TProperty;');
  Result.Add('begin');
  Result.Add('  Result := nil;');
  Result.Add('  if Index.TryParse(aName) then');
  Result.Add('    Result := FProperties[Index];');
  Result.Add('  if Assigned(Result) then exit;');
  Result.Add('  for Item in FItems do begin');
  Result.Add('    if (Item is TItemValue) and SameText(TItemValue(Item).Name,aName) then');
  Result.Add('      Exit(Item)');
  Result.Add('    else if (Item is TBaseComponent) and SameText(TBaseComponent(Item).Name,aName) then');
  Result.Add('      Exit(Item)');
  Result.Add('    else if (Item is TItemValue.TList) and SameText(TItemValue.TList(Item).Name,aName) then');
  Result.Add('      Exit(Item);');
  Result.Add('  end;');
  Result.Add('end;');

  Result.Add;
  Result.Add('procedure TBaseComponent.SetAsText(const Value: String);');
  Result.Add('begin');
  Result.Add('  raise Exception.Create(''Incomplete'');');
  Result.Add('end;');


  for lType in Types do
    Result.Add(GetMethodImp('TBaseComponent', lType, 'TProperty'));
  AddEnumHelperImp('TBaseComponent.TProperty',Result,'-');
end;

procedure TRFC5545.AddBaseValueIntf(var Result: TStringDynArray; var Types: TStringDynArray);
var
  Parameter: TParameter;
  Comma: String;
begin
  Result.Add;
  Result.Add('  TItemValue = class');
  Result.Add('  public');
  Result.Add('    type');
  Result.Add('      TList = class(TObjectList<TItemValue>)');
  Result.Add('      public');
  Result.Add('        function TryGetValue(const aName: String; out aValue: TItemValue): Boolean;');
  Result.Add('        procedure Build(Builder: TStringBuilder);');
  Result.Add('        function Name: String;');
  Result.Add('      end;');
  Result.Add('      TClassOf = class of TItemValue;');
  Result.Add('      TParameter = (');
  Comma := ' ';
  for Parameter in Parameters do begin
    Result.Add('          %s%s',[Comma,Parameter.ParamName.Replace('-','_')]);
    Comma := ',';
  end;
  Result.Add('        );');
  Result.Add('      TParamRec = record');
  Result.Add('        Name: String;');
  Result.Add('        Value: String;');
  Result.Add('      end;');
  Result.Add('      TParamRecDynArray = array of TParamRec;');
  AddEnumHelperIntf('      ','TParameter',Result);
  Result.Add('  public');
  Result.Add('    class function _ParseLine(const aText: String; out aName,aValue: String; out aParams: TParamRecDynArray): Boolean;');
  Result.Add('  protected');
  Result.Add('    Parameters: TDictionary<string,variant>;');
  Result.Add('    function GetName: String;');
  Result.Add('    function GetObject: TObject;');
  Result.Add('    procedure BuildValue(Builder: TStringBuilder); virtual;');
  Result.Add('    procedure SetValue(const aValue: String); virtual;');
  Result.Add('    function GetText: String; virtual;');
  Result.Add('    procedure SetText(const aValue: String); virtual;');
  Result.Add('    function GetParameter(Index: TItemValue.TParameter): Variant;');
  Result.Add('    procedure SetParameter(Index: TItemValue.TParameter; const aValue: Variant);');
  Result.Add('  public');
  Result.Add('    Name: String;');
  Result.Add('    Value: Variant;');
  Result.Add('    constructor Create(const AName: String; const aValue: Variant);');
  Result.Add('    destructor Destroy; override;');
  Result.Add('    procedure Build(Builder: TStringBuilder); virtual;');
  Result.Add('    property Text: String read GetText write SetText;');
  Result.Add('  end;');
  Result.Add;

  Result.Add('  TDateTimeValue = class(TItemValue)');
  Result.Add('  private');
  Result.Add('    FGMT: Boolean;');
  Result.Add('  protected');
  Result.Add('    procedure BuildValue(aBuilder: TStringBuilder); override;');
  Result.Add('    procedure SetValue(const aValue: String); override;');
  Result.Add('    property GMT: Boolean read FGMT write FGMT;');
  Result.Add('  end;');
  Result.Add;
end;

procedure TRFC5545.AddBaseValueImp(var Result: TStringDynArray);
begin
  Result.Add;
  Result.Add('{ TItemValue }');
  Result.Add;
  Result.Add('procedure TItemValue.BuildValue(Builder: TStringBuilder);');
  Result.Add('begin');
  Result.Add('  case varType(Value) of');
  Result.Add('    varEmpty,varNull');
  Result.Add('    :;');
  Result.Add('  else');
  Result.Add('    Builder.Append(varToStr(Value));');
  Result.Add('  end;');
  Result.Add('end;');

  Result.Add;
  Result.Add('function TItemValue.GetText: String;');
  Result.Add('// Will not perform folding');
  Result.Add('begin');
  Result.Add('  Result := TStringBuilder._Build(Build);');
  Result.Add('end;');

  Result.Add;
  Result.Add('class function TItemValue._ParseLine(const aText: String; out aName,aValue: String; out aParams: TParamRecDynArray): Boolean;');
  Result.Add('var');
  Result.Add('  Parser: TRegEx;');
  Result.Add('  Match: TMatch;');
  Result.Add('  lParamStart: Integer;');
  Result.Add('  Group: TGroup;');
  Result.Add('  lParamEnd: Integer;');
  Result.Add('begin');
  Result.Add('  aName := '''';');
  Result.Add('  aParams := [];');
  Result.Add('  aValue := '''';');
  Result.Add('  Result := False;');
  Result.Add('  Parser := TRegEx.Create(RegExItem);');
  Result.Add('  Match := Parser.Match(aText);');
  Result.Add('  // Paramters are between the name and a value');
  Result.Add('  lParamStart := 0;');
  Result.Add('  Group := Match.Groups[''name''];');
  Result.Add('  if Group.Success then begin');
  Result.Add('    Result := True;');
  Result.Add('    aName := Group.Value;');
  Result.Add('    lParamStart := Group.Length;');
  Result.Add('  end;');
  Result.Add('  Group := Match.Groups[''value''];');
  Result.Add('  if Group.Success then begin');
  Result.Add('    Result := True;');
  Result.Add('    aValue := Group.Value;');
  Result.Add('    lParamEnd := Group.Index;');
  Result.Add('  end;');
  Result.Add('  if Result then');
  Result.Add('    for Match in TRegEx.Create(RegExParams).Matches(aText.Substring(lParamStart,lParamEnd-lParamStart-2)) do begin');
  Result.Add('      SetLength(aParams,Length(aParams)+1);');
  Result.Add('      with aParams[High(aParams)] do begin');
  Result.Add('        Name := Match.Groups[''name''].Value;');
  Result.Add('        Value := Match.Groups[''value''].Value;');
  Result.Add('        if Value.Contains(''"'') then');
  Result.Add('          Value := Value.DeQuotedString(''"'');');
  Result.Add('      end;');
  Result.Add('    end;');
  Result.Add('end;');

  Result.Add;
  Result.Add('procedure TItemValue.SetText(const aValue: String);');
  Result.Add('// Assumes one line for the whole item');
  Result.Add('var');
  Result.Add('  lName: String;');
  Result.Add('  lValue: String;');
  Result.Add('  lParam: TItemValue.TParamRec;');
  Result.Add('  lParams: TItemValue.TParamRecDynArray;');
  Result.Add('begin');
  Result.Add('  if not _ParseLine(aValue,lName,lValue,lParams) then');
  Result.Add('    raise Exception.Create(''Set Text'');');
  Result.Add('  if lName <> '''' then');
  Result.Add('    Name := lName;');
  Result.Add('  SetValue(lValue);');
  Result.Add('  Parameters.Clear;');
  Result.Add('  for lParam in lParams do');
  Result.Add('    Parameters.AddOrSetValue(lParam.Name, lParam.Value);');
  Result.Add('end;');

  Result.Add;
  Result.Add('function TItemValue.GetName: String;');
  Result.Add('begin');
  Result.Add('  Result := Name');
  Result.Add('end;');

  Result.Add;
  Result.Add('function TItemValue.GetObject: TObject;');
  Result.Add('begin');
  Result.Add('  Result := Self');
  Result.Add('end;');

  Result.Add;
  Result.Add('function TItemValue.GetParameter(Index: TItemValue.TParameter): Variant;');
  Result.Add('begin');
  Result.Add('  if not Parameters.TryGetValue(Index.ToString,Result) then');
  Result.Add('    Value := Unassigned;');
  Result.Add('end;');

  Result.Add;
  Result.Add('procedure TItemValue.SetParameter(Index: TItemValue.TParameter; const aValue: Variant);');
  Result.Add('begin');
  Result.Add('  Parameters.AddOrSetValue(Index.ToString,aValue);');
  Result.Add('end;');

  Result.Add;
  Result.Add('constructor TItemValue.Create(const AName: String; const aValue: Variant);');
  Result.Add('begin');
  Result.Add('  inherited Create;');
  Result.Add('  Name := AName;');
  Result.Add('  Value := AValue;');
  Result.Add('  Parameters := TDictionary<string,variant>.Create;');
  Result.Add('end;');

  Result.Add;
  Result.Add('destructor TItemValue.Destroy;');
  Result.Add('begin');
  Result.Add('  inherited;');
  Result.Add('  FreeAndNil(Parameters)');
  Result.Add('end;');

  Result.Add;
  Result.Add('procedure TItemValue.Build(Builder: TStringBuilder);');
  Result.Add('var');
  Result.Add('  Pair: TPair<string,variant>;');
  Result.Add('  lValue: String;');
  Result.Add('begin');
  Result.Add('  Builder.Append(Name);');
  Result.Add('  for Pair in Parameters do begin');
  Result.Add('    lValue := varToStr(Pair.Value);');
  Result.Add('    if lValue.Contains('':'') or lValue.Contains('';'') or lValue.Contains(''"'') then');
  Result.Add('      lValue := lValue.QuotedString(''"'');');
  Result.Add('    Builder.AppendFormat('';%s=%s'',[Pair.Key,lValue]);');
  Result.Add('  end;');
  Result.Add('  Builder.Append('':'');');
  Result.Add('  BuildValue(Builder);');
  Result.Add('end;');

  Result.Add;
  Result.Add('procedure TItemValue.SetValue(const aValue: String);');
  Result.Add('begin');
  Result.Add('  Value := aValue;');
  Result.Add('end;');

  Result.Add;
  Result.Add('{ TItemValue.TList }');

  Result.Add;
  Result.Add('function TItemValue.TList.TryGetValue(const aName: String;');
  Result.Add('  out aValue: TItemValue): Boolean;');
  Result.Add('begin');
  Result.Add('  raise Exception.Create(''Error Message'');');
  Result.Add('end;');

  Result.Add;
  Result.Add('procedure TItemValue.TList.Build(Builder: TStringBuilder);');
  Result.Add('begin');
  Result.Add('  raise Exception.Create(''Error Message'');');
  Result.Add('end;');

  Result.Add;
  Result.Add('function TItemValue.TList.Name: String;');
  Result.Add('begin');
  Result.Add('  if Count > 0 then Exit(Self[0].Name);');
  Result.Add('  Result := '''';');
  Result.Add('end;');

  AddEnumHelperImp('TItemValue.TParameter',Result);

  Result.Add;
  Result.Add('{ TDateTimeValue }');

  Result.Add;
  Result.Add('procedure TDateTimeValue.BuildValue(aBuilder: TStringBuilder);');
  Result.Add('begin');
  Result.Add('  case varType(Value) of');
  Result.Add('    varDate');
  Result.Add('    : TISO8601._BuildDateTime(aBuilder, Value, GMT);');
  Result.Add('  else');
  Result.Add('    aBuilder.Append(varToStr(Value));');
  Result.Add('  end;');
  Result.Add('end;');

  Result.Add;
  Result.Add('procedure TDateTimeValue.SetValue(const aValue: String);');
  Result.Add('var');
  Result.Add('  lDateTime: TDateTime;');
  Result.Add('  lGMT: Boolean;');
  Result.Add('begin');
  Result.Add('  lGMT := False;');
  Result.Add('  if TISO8601._StrToDateTIme(aValue, lDateTime, lGMT) then');
  Result.Add('    Value := lDateTime');
  Result.Add('  else begin');
  Result.Add('    Value := aValue;');
  Result.Add('    lGMT := False;');
  Result.Add('  end;');
  Result.Add('  GMT := lGMT;');
  Result.Add('end;');
end;

procedure TRFC5545.AddCommonIntf(var Result: TStringDynArray);
begin
  Result.Add;
  Result.Add('  TStringBuilder_Helper = class helper for TStringBuilder');
  Result.Add('  public');
  Result.Add('    class function _Build(Proc: TProc<TStringBuilder>): String;');
  Result.Add('  end;');

//  Result.Add;
//  Result.Add('  IItem = interface');
//  Result.Add('    function GetName: String;');
//  Result.Add('    function GetObject: TObject;');
//  Result.Add('    procedure Build(Builder: TStringBuilder);');
//  Result.Add('  end;');

  Result.Add;
  Result.Add('  TISO8601 = record');
  Result.Add('  private');
  Result.Add('    const _rxTimeIdx = 5;');
  Result.Add('    const _rxGMTIdx = 9;');
  Result.Add('  public');
  Result.Add('    class var _RegExDateTime: TRegEx;');
  Result.Add('    class constructor Create;');
  Result.Add('    class function _BuildDateTime(aBuilder: TStringBuilder; const aValue: TDateTime; aGMT: Boolean): Boolean; static;');
  Result.Add('    class function _StrToDateTime(const aText: String; out aValue: TDateTime; out gmt: Boolean): Boolean; static;');
  Result.Add('    class function _DateTimeToStr(aValue: TDateTime; aGMT: Boolean): String; static;');
  Result.Add('  end;');

end;

procedure TRFC5545.AddCommonImp(var Result: TStringDynArray);
begin
  Result.Add;
  Result.Add('class function TStringBuilder_Helper._Build(Proc: TProc<TStringBuilder>): String;');
  Result.Add('var');
  Result.Add('  Builder: TStringBuilder;');
  Result.Add('begin');
  Result.Add('  Builder := TStringBuilder.Create;');
  Result.Add('  try');
  Result.Add('    Proc(Builder);');
  Result.Add('    Result := Builder.ToString;');
  Result.Add('  finally');
  Result.Add('    Builder.Free;');
  Result.Add('  end');
  Result.Add('end;');

  Result.Add;
  Result.Add('class constructor TISO8601.Create;');
  Result.Add('begin');
  Result.Add('  inherited;');
  Result.Add('  _RegExDateTime := TRegEx.Create(');
  Result.Add('    ''^\ *?(?<date>'' // 1');
  Result.Add('      +''(?<year>[12]\d{3})'' // 2');
  Result.Add('      +''(?<month>[01]\d)'' // 3');
  Result.Add('      +''(?<day>[0-3]\d)'' // 4');
  Result.Add('    +'')?''');
  Result.Add('    +''T?''');
  Result.Add('    +''(?<time>'' // 5 count 6');
  Result.Add('      +''(?<hour>[0-2]\d)'' // 6');
  Result.Add('      +''(?<minute>[0-5]\d)'' // 7');
  Result.Add('      +''(?<second>[0-6]\d)'' // 8');
  Result.Add('      +''(?<gmt>Z)?'' // 9 count 10');
  Result.Add('    +'')?\ *?$'');');
  Result.Add('end;');

  Result.Add;
  Result.Add('class function TISO8601._BuildDateTime(aBuilder: TStringBuilder; const aValue: TDateTime; aGMT: Boolean): Boolean;');
  Result.Add('var');
  Result.Add('  Start: Integer;');
  Result.Add('begin');
  Result.Add('  Result := False;');
  Result.Add('  if aValue = 0 then exit;');
  Result.Add('  Start := aBuilder.Length;');
  Result.Add('  if Frac(aValue) = 0 then // Date only');
  Result.Add('    aBuilder.Append(FormatDateTime(''yyyymmdd'',aValue));');
  Result.Add('  if Trunc(aValue) = 0 then begin // Time Only');
  Result.Add('    if Start <> aBuilder.Length then');
  Result.Add('      aBuilder.Append(''T'');');
  Result.Add('    aBuilder.Append(FormatDateTime(''hhmmss'',aValue));');
  Result.Add('    if aGMT then');
  Result.Add('      aBuilder.Append(''Z'');');
  Result.Add('  end;');
  Result.Add('  Result := True;');
  Result.Add('end;');

  Result.Add;
  Result.Add('class function TISO8601._DateTimeToStr(aValue: TDateTime; aGMT: Boolean): String;');
  Result.Add('var');
  Result.Add('  lResult: String;');
  Result.Add('begin');
  Result.Add('  Result := TStringBuilder._Build(procedure(aBuilder: TStringBuilder)');
  Result.Add('  begin');
  Result.Add('    _BuildDateTime(aBuilder, aValue, aGMT);');
  Result.Add('  end);');
  Result.Add('end;');
  Result.Add('');
  Result.Add('class function TISO8601._StrToDateTime(const aText: String; out aValue: TDateTime; out gmt: Boolean): Boolean;');
  Result.Add('var');
  Result.Add('  Match: TMatch;');
  Result.Add('begin');
  Result.Add('  Match := _RegExDateTime.Match(aText);');
  Result.Add('  Result := FAlse;');
  Result.Add('  if not Match.Success then exit;');
  Result.Add('  case (Ord(Match.Groups[''date''].Length <> 0) shl 1)');
  Result.Add('      or Ord((Match.Groups.Count > _rxTimeIdx) and (Match.Groups[''time''].Length <> 0)) of');
  Result.Add('    3: begin');
  Result.Add('         aValue := EncodeDateTime(');
  Result.Add('          Match.Groups[''year''].Value.ToInteger,');
  Result.Add('          Match.Groups[''month''].Value.ToInteger,');
  Result.Add('          Match.Groups[''day''].Value.ToInteger,');
  Result.Add('          Match.Groups[''hour''].Value.ToInteger,');
  Result.Add('          Match.Groups[''minute''].Value.ToInteger,');
  Result.Add('          Match.Groups[''second''].Value.ToInteger,');
  Result.Add('          0');
  Result.Add('         );');
  Result.Add('       end;');
  Result.Add('    2: aValue := EncodeDate(');
  Result.Add('        Match.Groups[''year''].Value.ToInteger,');
  Result.Add('        Match.Groups[''month''].Value.ToInteger,');
  Result.Add('        Match.Groups[''day''].Value.ToInteger');
  Result.Add('       );');
  Result.Add('    1: begin');
  Result.Add('         aValue := EncodeTime(');
  Result.Add('          Match.Groups[''hour''].Value.ToInteger,');
  Result.Add('          Match.Groups[''minute''].Value.ToInteger,');
  Result.Add('          Match.Groups[''second''].Value.ToInteger,');
  Result.Add('          0');
  Result.Add('         );');
  Result.Add('       end;');
  Result.Add('  end;');
  Result.Add('  gmt := (Match.Groups.Count > _rxGMTIdx) and (Match.Groups[''gmt''].Length <> 0); // check for the presents of a Z at the end');
  Result.Add('  Result := True;');
  Result.Add('end;');
  Result.Add;
end;

procedure TRFC5545.AddCommonConsts(var Result: TStringDynArray);
begin
  Result.Add;
  Result.Add('  // http://qaru.site/questions/3203404/c-regex-parse-file-in-ical-format-and-populate-object-with-results');
  Result.Add('  RegExItem = ''^(?<name>[^[:cntrl:]";:,\n]+|)!*(?<parameter>;(?<param_name>[^[:cntrl:]";:,\n]+)=(?<param_value>''');
  Result.Add('     +''(?:(?:[^\S\n]|[^[:cntrl:]";:,])*|"(?:[^\S\n]|[^[:cntrl:]"])*")(?:,(?:(?:[^\S\n]|[^[:cntrl:]";:,])*|"(?:[^\S\n]|[^[:cntrl:]"])*"))*))*:(?<value>(?:[^\S\n]|[^[:cntrl:]])*)$'';');
  Result.Add('  RegExParams='';(?<name>[^=^;]+)=(?<value>[^;]+)'';');
end;

procedure TRFC5545.AddComponentImp(var Result: TStringDynArray; const Component: TComponent);
var
  lComp: TComponent.TComp;
  lType: TType;
  lTypeName: String;
begin
  lTypeName := 'T'+ Component.CompName;
  Result.Add('{ %s }',[lTypeName]);
  Result.Add;
  Result.Add('class function %s._DefaultName: String;',[lTypeName]);
  Result.Add('begin');
  Result.Add('  Result := ''%s'';',[Component.Component_Name.Join(' ')]);
  Result.Add('end;');
  Result.Add;
  for lComp in Component.Comps do begin
    if lComp.Item = Component then continue;
    Result.Add('function %1:s.%0:s_Add: T%0:s;',[lComp.Item.CompName,lTypeName]);
    Result.Add('begin');
    Result.Add('  Result := T%0:s.Create;',[lComp.Item.CompName]);
    Result.Add('  FItems.Add(Result);');
    Result.Add('end;');
    Result.Add;
    Result.Add('function %1:s.%0:s_Count: Integer;',[lComp.Item.CompName,lTypeName]);
    Result.Add('begin');
    Result.Add('  Result := Length(%0:ss);',[lComp.Item.CompName]);
    Result.Add('end;');
    Result.Add;
  end;
end;

procedure TRFC5545.AddComponentIntf(var Result: TStringDynArray; const Component: TComponent);
var
  lTypeName,lGetterSetter,lGetterSetters: String;
  lProp: TComponent.TProp;
  lComp: TComponent.TComp;
  lComment: String;
  lPropParam: TProperty.TParam;
  lNameProp: TComponent.TNameProp;
  lPropNameUsed: TStringDynArray;
  lCorrectedName: String;
  lType: TType;
begin
  lTypeName := 'T'+ Component.CompName;
  Result.Add('  %s = class(TBaseComponent)',[lTypeName]);
  Result.Add('  protected');
  Result.Add('    class function _DefaultName: String; override;');
  Result.Add('  public');
  for lComp in Component.Comps do begin
    if lComp.Item = Component then continue;
    Result.Add('    %0:ss: array of T%0:s;',[lComp.Item.CompName]);
  end;
  for lComp in Component.Comps do begin
    if lComp.Item = Component then continue;
    Result.Add('    function %0:s_Add: T%0:s;',[lComp.Item.CompName]);
    Result.Add('    function %0:s_Count: Integer;',[lComp.Item.CompName]);
  end;
  lPropNameUsed := [];
  for lProp in Component.Props do
    for lNameProp in lProp.NameProps do begin
      if lPropNameUsed.AddUnique(lNameProp.Name) then
        lComment := ''
      else
        lComment := '// Dup? ';
      lCorrectedName := lNameProp.&Property.PropName.Replace('-','_');
      if Length(lNameProp.&Property.Parameters) <> 0 then
        Result.Add('%1:s    property %0:s_Add: TItemValue Index TBaseComponent.TProperty.%0:s read NewItemValue;',[lCorrectedName,lComment]);
    end;
  Result.Add('  public');
  lPropNameUsed := [];
  for lProp in Component.Props do begin
    Result.Add('    //%s',[lProp.Comments]);
    for lNameProp in lProp.NameProps do begin
//      lCorrectedName := lProp.FixName(lName.lName);
      lCorrectedName := lNameProp.&Property.PropName.Replace('-','_');
      if lPropNameUsed.AddUnique(lCorrectedName) then
        lComment := ''
      else
        lComment := '// Dup? ';
      lNameProp.&Property.AddXMLDoc_Summary('    ',Result);
      for lPropParam in lNameProp.&Property.Parameters do
        lPropParam.Parameter.AddComment('    ',Result);
      TType.AddXMLDoc_Returns(lNameProp.&Property.&Type.Items,'    ',Result);
      if SameText(lCorrectedName,'X_') or SameText(lCorrectedName,'IANA_') then begin
        Result.Add('%1:s    property %0:s;',[lCorrectedName,lComment]);
        Result.Add('%1:s    property %0:s_;',[lCorrectedName,lComment]);
        Result.Add('%1:s    property %0:sCount;',[lCorrectedName,lComment]);
      end
      else begin
        if Length(lNameProp.&Property.Parameters) = 0 then begin
          if [TOccurance.MAY_occur_more_than_once] * lProp.Occurances <> [] then
            Result.Add('%1:s    property %0:s[Index: Integer]: Variant index TBaseComponent.TProperty.%0:s read GetValues write SetValues;',[lCorrectedName,lComment])
          else
  //        if [TOccurance.MUST_NOT_occur_more_than_once,
  //            TOccurance.MUST_NOT_occur_more_than_once] * lProp.Occurances <> [] then
            Result.Add('%1:s    property %0:s: Variant index TBaseComponent.TProperty.%0:s read GetValue write SetValue;',[lCorrectedName,lComment]);
        end
        else begin
          if [TOccurance.MAY_occur_more_than_once] * lProp.Occurances <> [] then
            Result.Add('%1:s    property %0:s[Index: Integer]: TItemValue index TBaseComponent.TProperty.%0:s read GetItemValues;',[lCorrectedName,lComment])
          else
//            if [TOccurance.SHOULD_NOT_occur_more_than_once,
//              TOccurance.MUST_NOT_occur_more_than_once] * lProp.Occurances <> [] then
            Result.Add('%1:s    property %0:s: TItemValue index TBaseComponent.TProperty.%0:s read GetItemValue;',[lCorrectedName,lComment]);
        end;
        if [TOccurance.MAY_occur_more_than_once] * lProp.Occurances <> [] then
          Result.Add('%1:s    property %0:s_Count: Integer index TBaseComponent.TProperty.%0:s read GetValuesCount write SetValuesCount;',[lCorrectedName,lComment]);
      end;
    end;
  end;
  Result.Add('  end;');
  Result.Add;
end;

procedure TRFC5545.AddEnumHelperImp(const TypeName: String; var Lines: TStringDynArray; Space: Char = '-');
begin
  Lines.Add;
  Lines.Add('{ %s_Helper }',[TypeName]);
  Lines.Add;
  Lines.Add('function %s_Helper.TryParse(const aValue: String): Boolean;',[TypeName]);
  Lines.Add('var');
  Lines.Add('  Index: Integer;');
  Lines.Add('begin');
  Lines.Add('  Index := GetEnumValue(TypeInfo(%s),aValue.Replace(''%s'',''_''));',[TypeName,Space]);
  Lines.Add('  Result := Index >= 0;');
  Lines.Add('  if Result then');
  Lines.Add('    Self := %s(Index);',[TypeName]);
  Lines.Add('end;');
  Lines.Add;
  Lines.Add('function %s_Helper.ToString: String;',[TypeName]);
  Lines.Add('begin');
  Lines.Add('  Result := GetEnumName(TypeInfo(%s),Ord(Self)).Replace(''_'',''%s'');',[TypeName,Space]);
  Lines.Add('end;');
end;

procedure TRFC5545.AddEnumHelperIntf(const Indent, TypeName: String; var Lines: TStringDynArray);
begin
  Lines.Add('%s%s_Helper = record helper for %1:s',[Indent,Typename]);
  Lines.Add('%spublic',[Indent]);
  Lines.Add('%s  function TryParse(const aValue: String): Boolean;',[Indent]);
  Lines.Add('%s  function ToString: String;',[Indent]);
  Lines.Add('%send;',[Indent]);
end;

procedure TRFC5545.ChangeProperty(aPropName: String; const Proc: TProc<TProperty>);
var
  Index: Integer;
  &Property: TProperty;
begin
  Index := Properties.Count - 1;
  aPropName := aPropName.Replace('_','-');
  while (Index >= 0) and not SameText(Properties[Index].PropName, aPropName) do
    Dec(Index);
  if Index < 0 then
    raise Exception.CreateFmt('Shouldn''t Happen <%s>',[aPropName]);
  Proc(Properties[Index]);
end;

function TRFC5545.GetParameter(aParamName: String): TParameter;
var
  Index: Integer;
  &Property: TProperty;
begin
  Index := Parameters.Count - 1;
  aParamName := aParamName.Replace('_','-').Replace('"','');
  while (Index >= 0) and not SameText(Parameters[Index].ParamName, aParamName) do
    Dec(Index);
  if Index < 0 then
    raise Exception.CreateFmt('Shouldn''t Happen <%s>',[aParamName]);
  Result := Parameters[Index];
end;


procedure TRFC5545.DoSections(const SectionPrefix: String; ProcessSection: TProcessSection);
var
  Index: Integer;
  Mode: (_,ParameterStart,InParameter,NewSection);
  Line: String;
  Lines: TStringDynArray;
begin
  Mode := _;
  for Index := 0 to Doc.Count-1 do begin
    Line := Doc[Index];
    if Line.StartsWith(SectionPrefix) then
      Mode := ParameterStart
    else if (Line.Length > 0) and Line[1].IsDigit then
      Mode := NewSection;
    case Mode of
      _: Continue;
      ParameterStart
      : begin
          if Length(Lines) > 0 then
            ProcessSection(Lines);
          Lines := [Line];
          Mode := InParameter;
        end;
      InParameter
      : begin
          SetLength(Lines,Length(Lines)+1);
          Lines[High(Lines)] := Line;
        end;
      NewSection
      : begin
          if Length(Lines) > 0 then
            ProcessSection(Lines);
          Lines := [];
          Mode := _;
        end;
    end;
  end;


end;

function TRFC5545.GenerateDelphi(const UnitName: string): TStringDynArray;
var
  Types: TStringDynArray;
  Component: TComponent;

begin
  Result := [];
  Types := [];
  Result.Add('unit %s;',[UnitName]);
  Result.Add('{$SCOPEDENUMS ON}');
  Result.Add('interface');
  Result.Add;
  Result.Add('uses System.TypInfo,');
  Result.Add('  System.Classes,');
  Result.Add('  System.SysUtils,');
  Result.Add('  System.Variants,');
  Result.Add('  System.Generics.Collections,');
  Result.Add('  System.DateUtils,');
  Result.Add('  System.RegularExpressions;');
  Result.Add;
  Result.Add('const');
  AddCommonConsts(Result);
  Result.Add;
  Result.Add('type');
  AddCommonIntf(Result);
  Result.Add;
  for Component in Components do
    Result.Add('  T%s = class;',[Component.CompName]);

  AddBaseValueIntf(Result,Types);
  AddBaseComponentIntf(Result,Types);
  for Component in Components do
    AddComponentIntf(Result,Component);

  Result.Add('implementation');
  AddCommonImp(Result);
  AddBaseValueImp(Result);
  AddBaseComponentImp(Result,Types);
  for Component in Components do
    AddComponentImp(Result,Component);
  Result.Add('end.');
end;

function TRFC5545.GetMethodImp(aClass,aType,aIndexType: String): TStringDynArray;
begin
  Result := [];
  Result.Add;
  Result.Add('function %2:s.Get%0:s(Index: %1:s): T%0:s;',[aType,aIndexType,aClass]);
  Result.Add('begin');
  Result.Add('  Result := GetItem<T%s>(Index.ToString);',[aType]);
  Result.Add('end;');
end;

function TRFC5545.GetMethodIntf(const Indent: String; aType,aIndexType: String): String;
begin
  Result := Format('%sfunction Get%1:s(Index: %2:s): T%1:s;',[Indent,aType,aIndexType]);
end;

procedure TRFC5545.Load(const URL: string);
var
  HTTPs: TIdHTTP;
  SSL: TIdSSLIOHandlerSocketOpenSSL;
  URI: TURI;
  S: TArray<String>;
begin
  Doc.Clear;
  URI := TURI.Create(URL);
  S := URI.Path.Split(['/']);
  if TFile.Exists(S[High(S)]) then
    Doc.LoadFromFile(S[High(S)])
  else begin
    HTTPs := TIdHTTP.Create(nil);
    SSL := TIdSSLIOHandlerSocketOpenSSL.Create(Nil);

    HTTPs.IOHandler := SSL;
    SSL.SSLOptions.Method := sslvTLSV1;
    SSL.SSLOptions.Mode := sslmUnassigned;
    try
      Doc.Text := HTTPs.Get(URL);
      Doc.SaveToFile(S[High(S)]);
    finally
      FreeAndNil(SSL);
      FreeAndNil(HTTPs);
    end;
  end;
end;

procedure TRFC5545.Parse;
begin
  RemovePageBreaks;
  DoSections('3.3.',ProcessTypes);
  DoSections('3.2.',ProcessParam);
  DoSections('3.8.',ProcessProperties);
  DoSections('3.7.',ProcessProperties);
  DoSections('3.6.',ProcessComponent);
  Process;
end;

procedure TRFC5545.Process;
var
  &Property: TProperty;
  Component: TComponent;
  Index: Integer;
begin
  for &Property in Properties do begin
    for Index := Low(&Property.Parameters) to High(&Property.Parameters) do
      ProcessPropertyParam(&Property.Parameters[Index]);
    &Property.&Type := Types.ValueNameTo(&Property.Value_Type.Join)
  end;
  for Component in Components do begin
    for Index := Low(Component.Props) to High(Component.Props) do
      ProcessComponentProp(Component.Props[Index]);
    ProcessComponentSubs(Component);
  end;

end;

procedure TRFC5545.ProcessComponentProp(var aProp: TComponent.TProp);
var
  NIndex: Integer;
  Prop: ^TComponent.TProp;
begin
  Prop := @aProp;
  if [TOccurance.MUST_NOT_occur_more_than_once
       ,TOccurance.SHOULD_NOT_occur_more_than_once] * Prop.Occurances <> [] then begin
    for NIndex := Low(Prop.NameProps) to High(Prop.NameProps) do
      ChangeProperty(Prop.FixName(Prop.NameProps[NIndex].Name),procedure(aProperty: TProperty)
      begin
        Include(aProperty.InstanceTypes,TProperty.TInstanceType.Single);
        Prop.NameProps[NIndex].&Property := aProperty;
      end);
  end;
  if [TOccurance.MAY_occur_more_than_once] * Prop.Occurances <> [] then begin
    for NIndex := Low(Prop.NameProps) to High(Prop.NameProps) do
      ChangeProperty(Prop.FixName(Prop.NameProps[NIndex].Name),procedure(aProperty: TProperty)
      begin
        Include(aProperty.InstanceTypes,TProperty.TInstanceType.Multiple);
        Prop.NameProps[NIndex].&Property := aProperty;
      end);
  end;
  if Prop.Occurances -[TOccurance.REQUIRED,TOccurance.OPTIONAL] = [] then // no markings
    for NIndex := Low(Prop.NameProps) to High(Prop.NameProps) do
      ChangeProperty(Prop.FixName(Prop.NameProps[NIndex].Name),procedure(aProperty: TProperty)
      begin
        Include(aProperty.InstanceTypes,TProperty.TInstanceType.Single);
        Prop.NameProps[NIndex].&Property := aProperty;
      end);

end;

procedure TRFC5545.ProcessParam(const Lines: TStringDynArray);
begin
  if Lines.Count = 0 then exit;
  if Lines[0].StartsWith('3.2. ') then exit;
  Parameters.Add(TParameter.Create(Lines));
end;

procedure TRFC5545.ProcessProperties(const Lines: TStringDynArray);
begin
  if Lines.Count = 0 then exit;
  if Lines[0].StartsWith('3.7. ') then exit;
  Properties.Add(TProperty.Create(Lines));
  if Properties.Last.Property_Name.Count = 0 then
   Properties.Delete(Properties.Count-1);

end;

procedure TRFC5545.ProcessComponent(const Lines: TStringDynArray);
begin
  if Lines.Count = 0 then exit;
  if Lines[0].StartsWith('3.8.2. ') then exit;
  Components.Add(TComponent.Create(Lines));
end;

procedure TRFC5545.ProcessTypes(const Lines: TStringDynArray);
begin
  if Lines.Count = 0 then exit;
  if Lines[0].StartsWith('3.3. ') then exit;
  Types.Add(TType.Create(Lines));
end;

procedure TRFC5545.ProcessComponentSubs(aComp: TComponent);
var
  lDefIndex: Integer;
  lCompIndex: Integer;
  lComponent: TComponent;
begin
  for lDefIndex := Low(aComp.Definations) to High(aComp.Definations) do
    with aComp.Definations[lDefIndex] do
      for lCompIndex := Low(Comps) to High(Comps) do
        for lComponent in Self.Components do
          if lComponent.IsComponentName(Comps[lCompIndex].Name) then begin
            Comps[lCompIndex].Item := lComponent;
            Break;
          end;
end;

procedure TRFC5545.ProcessPropertyParam(var aParam: TProperty.TParam);
begin
  aParam.Parameter := GetParameter(TProperty.TParam.FixName(aParam.Name));
end;

procedure TRFC5545.RemovePageBreaks;
var
  Index: Integer;
begin
  Index := Doc.Count - 1;
  while (Index >= 0) do begin
    if Doc[Index].Contains('[Page') then begin
      if Index < Doc.Count then
        Doc.Delete(Index); // Desruisseaux                Standards Track                     [Page 1]
      if Index < Doc.Count then
        Doc.Delete(Index); // ??
      if Index < Doc.Count then
        Doc.Delete(Index) // RFC 5545                       iCalendar                  September 2009
      else
        Dec(Index);
      while (Index < Doc.Count) and (Doc[Index].Trim = '') do
        Doc.Delete(Index);
      if Index >= Doc.Count then
        Index := Doc.Count;
      while (Index -1 > 0) and (Doc[Index-1].Trim = '') do begin
        Doc.Delete(Index-1);
        Dec(Index);
      end;
    end;
    Dec(Index);
  end;
  Doc.SaveToFile('xxx.txt');;
end;

function TStringDynArray_Helper.Add(const aValue: String): Integer;
begin
  Result := Count;
  Insert(Result,aValue);
end;

function TStringDynArray_Helper.Add(const aValue: String; const aArgs: array of const): Integer;
begin
  Result := Add(Format(aValue,aArgs));
end;

function TStringDynArray_Helper.Add: Integer;
begin
  Add('');
end;

function TStringDynArray_Helper.Add(const aValues: TStringDynArray): Integer;
var
  aValue: String;
begin
  Result := -1;
  for aValue in aValues do
    Result := Add(aValue);
end;

function TStringDynArray_Helper.AddUnique(const aValue: String): Boolean;
begin
  Result := IndexOf(aValue) < 0;
  if Result then
    Add(aValue);
end;

function TStringDynArray_Helper.Contains(const aValue: String; IgnoreCase: Boolean = True): Boolean;
begin
  Result := IndexOf(aValue,IgnoreCase) >= 0;
end;

function TStringDynArray_Helper.IndexOf(const aValue: String; IgnoreCase: Boolean = True): Integer;
begin
  Result := High(Self);
  if IgnoreCase then
    while (Result >= Low(Self)) and not SameText(Self[Result],aValue) do
      Dec(Result)
  else
    while (Result >= Low(Self)) and (Self[Result] <> aValue) do
      Dec(Result)


end;

procedure TStringDynArray_Helper.Delete(aIndex: Integer; Count: Integer = 1);
begin
  System.Delete(Self,aIndex,Count);
end;

function TStringDynArray_Helper.GetCount: Integer;
begin
  Result := Length(Self);
end;

procedure TStringDynArray_Helper.Insert(aIndex: Integer; const aValue: String);
begin
  System.Insert(aValue,Self,aIndex);
end;

function TStringDynArray_Helper.Join(const Delim: String = ','): string;
begin
  Result := String.Join(Delim,Self);
end;

procedure TStringDynArray_Helper.LoadFromFile(const FileName: String);
begin
  Self := TFile.ReadAllLines(FileName);
end;

procedure TStringDynArray_Helper.SaveToFile(const FileName: String);
begin
  TFile.WriteAllLines(FileName,Self);
end;

procedure TStringDynArray_Helper.SetCount(const Value: Integer);
begin
  SetLength(Self,Value);
end;

procedure TStringDynArray_Helper.Trim;
begin
  while (Count > 0) and (Self[0].Trim = '') do
    Delete(0);
  while (Count > 0) and (Self[High(Self)].Trim = '') do
    Delete(High(Self));
end;

constructor TParameter.Create(const aLines: TStringDynArray);
var
  Index: Integer;
  Line: String;
  Section: String;
  Field: TParameter.TField;
  OldField: TParameter.TField;
  Mode: (_,_NewSection,_InSection);
begin
  Section := 'Name';
  Lines := aLines;
  Lines.Trim;
  Line := aLines[0];
  FSections[TParameter.TField.Name] := [Line.SubString(Line.IndexOf(' ')).Trim];
  Mode := _;
  Field := Low(Field);
  OldField := Low(OldField);
  for Index := Succ(Low(aLines)) to High(aLines) do begin
    Line := aLines[Index];
    if Line.Contains(':') and (Line.Length > 5) and Line.StartsWith('  ') and not Line.StartsWith('    ') then begin
      Section := Line.Substring(0,Line.IndexOf(':')).Trim;
      if not Field.TryParse(Section) then
        raise Exception.CreateFmt('Unknown section %s',[Line]);
      Line := Line.SubString(Line.IndexOf(':')+1).Trim;
      Mode := _NewSection;
    end;
    case Mode of
      _: if Line.Trim.Length = 0 then continue;
      _NewSection
      : begin
          FSections[OldField].Trim;
          if Line <> '' then
            FSections[Field] := [Line]
          else
            FSections[Field] := [];
          Mode := _InSection;
        end;
      _InSection
      : if (Line = '') then
          FSections[Field].Add('')
        else if Line.StartsWith('     ') then
          FSections[Field].Add(Line.Remove(0,5))
        else
          raise Exception.Create('Shouldn''t Happen');
    end;
    OldField := Field;
  end;
  FSections[OldField].Trim;
end;

procedure TParameter.AddComment(const Indent: String; var Lines: TStringDynArray);
begin
  Lines.Add('%s/// <param name="%s" />',[Indent,ParamName]);
end;

function TParameter.ParamName: String;
begin
  Result := UpperCase(Parameter_Name.Join(' ').Trim);
end;

function TParameter.XMLDocs: IXMLDocument;
var
  Doc: TXMLDocument;
  Item: IXMLNode;
begin
  Result := NewXMLDocument;// TXMLDocument.Create(nil);
  Item := Result.AddChild('summary');
  Item.Text := FSections[TParameter.TField.Name].Join;
  Item := Result.AddChild('remarks');
  Item.Text := Lines.Join(#13#10);
end;

{ TParameter.TField_Helper }

function TParameter.TField_Helper.TryParse(const aValue: String): Boolean;
var
  Index: Integer;
begin
  if SameText(aValue,'Examples') then
    Self := TParameter.TField.Example
  else begin
    Index := GetEnumValue(TypeInfo(TParameter.TField),aValue.Replace(' ','_'));
    Result := Index >= 0;
    if Result then
      Self := TParameter.TField(Index);
  end;
end;

function TParameter.TField_Helper.ToString: String;
begin
  Result := GetEnumName(TypeInfo(TParameter.TField),Ord(Self)).Replace('_',' ');
end;

constructor TProperty.Create(const aLines: TStringDynArray);
var
  Index: Integer;
  Line: String;
  Section: String;
  Field: TProperty.TField;
  OldField: TProperty.TField;
  Mode: (_,_NewSection,_InSection);
begin
  Section := 'Name';
  Lines := aLines;
  Lines.Trim;
  InstanceTypes := [];
  Line := aLines[0];
  FSections[TProperty.TField.Name] := [Line.SubString(Line.IndexOf(' ')).Trim];
  Mode := _;
  Field := Low(Field);
  OldField := Low(OldField);
  for Index := Succ(Low(aLines)) to High(aLines) do begin
    Line := aLines[Index];
    if Line.Contains(':') and (Line.Length > 5) and Line.StartsWith('  ') and not Line.StartsWith('    ') then begin
      Section := Line.Substring(0,Line.IndexOf(':')).Trim;
      if not Field.TryParse(Section) then
        raise Exception.CreateFmt('Unknown section %s',[Line]);
      Line := Line.SubString(Line.IndexOf(':')+1).Trim;
      Mode := _NewSection;
    end;
    case Mode of
      _: if Line.Trim.Length = 0 then continue;
      _NewSection
      : begin
          FSections[OldField].Trim;
          if Line <> '' then
            FSections[Field] := [Line]
          else
            FSections[Field] := [];
          Mode := _InSection;
        end;
      _InSection
      : if (Line = '') then
          FSections[Field].Add('')
        else if Line.StartsWith('      ') then
          FSections[Field].Add(Line.Remove(0,6))
        else if Line.StartsWith('    ') then
          FSections[Field].Add(Line.Remove(0,4))
        else if Line.StartsWith('   ') then
          FSections[Field].Add(Line.Remove(0,3))
        else
          raise Exception.Create('Shouldn''t Happen');
    end;
    OldField := Field;
  end;
  FSections[OldField].Trim;
  Parse;
end;

procedure TProperty.AddXMLDoc_Summary(const Indent: String; var Lines: TStringDynArray);
begin
  Lines.Add('%s/// <summary>%s</summary>',[Indent,Name.Join]);
end;

function TProperty.ObjType: String;
var
  lName: String;
  Index: Integer;
  First: Boolean;
begin
  Result := Value_Type[0];
  if Result.Contains(' ') then begin
    lName := PropName;
    if SameText(lName,'ATTACH') or SameText(lName,'X-') or SameText(lName,'IANA-') then
      Result := 'Value'
    else if SameText(lName,'GEO') then
      Result := 'TEXT'
    else if Result.StartsWith('The default value type') then begin
      Result := Result.Remove(0,Length('The default value type')).Replace('.',' ');
      while (Result.Length > 0) and (Result[Low(Result)].IsLower or Result[Low(Result)].IsSeparator) do
        Result := Result.Substring(1);

      if Result.Contains(' ') then
        Result := Result.Substring(0,Result.IndexOf(' '));
    end;
  end;
  First := True;
  for Index := Low(Result) to High(Result) do
    if Result[Index].IsLower then begin
      if First then
        Dec(Result[Index],(Ord('a')- Ord('A')));
      First := False;
    end
    else if Result[Index].IsUpper then begin
      if not First then
        Inc(Result[Index],(Ord('a')- Ord('A')));
      First := False;
    end
    else
      First := True;
  Result := Result.Replace('-','');
end;

procedure TProperty.Parse;
var
  Line: String;
  Mode: (_,InParam,InComment,InSection);
  Item: String;
  Items: TArray<String>;
  Occurances: TOccurances;
begin
  Occurances := [];
  Mode := _;
  for Line in Format_Definition do begin
    Item := '';
    if line.Trim = '' then continue;
    Items := Line.Split(['=']);
    if Line.Contains('=') then
      if Items[0].Trim.EndsWith('param') then begin
        Mode :=  InParam;
        TParam.TryAdd(Parameters, Items[1], Occurances);
      end
      else
        Mode := _;
    case Line.Trim[1] of
      ';'
      : begin
          if Mode <> InComment then
            Occurances := [];
          Mode := InComment;
          Occurances := Occurances + TOccurances.Contains(Line);
        end;
      '('
      : begin
          Mode := InSection;
          for Item in Line.Split(['/']) do
            TParam.TryAdd(Parameters,Item, Occurances);
        end;
    end;
  end;




end;

function TProperty.PropName: String;
begin
  Result := Property_Name.Join(' ').Trim;
  if SameText(Result,'Class')
      or SameText(Result,'Repeat') then
    Result := '&' + Result
  else if Result.Contains(' IANA-registered') then
    Result := 'IANA-'
  else if Result.Contains('"X-"') then
    Result := 'X-';


end;

function TProperty.XMLDocs: IXMLDocument;
var
  Doc: TXMLDocument;
  Item: IXMLNode;
begin
  Result := NewXMLDocument;// TXMLDocument.Create(nil);
  Item := Result.AddChild('summary');
  Item.Text := FSections[TProperty.TField.Name].Join;
  Item := Result.AddChild('remarks');
  Item.Text := Lines.Join(#13#10);
end;

{ TProperty.TField_Helper }

function TProperty.TField_Helper.TryParse(const aValue: String): Boolean;
var
  Index: Integer;
begin
  Index := GetEnumValue(TypeInfo(TProperty.TField),aValue.Replace(' ','_'));
  Result := Index >= 0;
  if Result then
    Self := TProperty.TField(Index);
end;

function TProperty.TField_Helper.ToString: String;
begin
  Result := GetEnumName(TypeInfo(TProperty.TField),Ord(Self)).Replace('_',' ');
end;

constructor TComponent.Create(const aLines: TStringDynArray);
var
  Index: Integer;
  Line: String;
  Section: String;
  Field: TComponent.TField;
  OldField: TComponent.TField;
  Mode: (_,_NewSection,_InSection);
begin
  Section := 'Name';
  Lines := aLines;
  Lines.Trim;
  Line := aLines[0];
  FSections[TComponent.TField.Name] := [Line.SubString(Line.IndexOf(' ')).Trim];
  Mode := _;
  Field := Low(Field);
  OldField := Low(OldField);
  for Index := Succ(Low(aLines)) to High(aLines) do begin
    Line := aLines[Index];
    if Line.Contains(':') and (Line.Length > 5) and Line.StartsWith('  ') and not Line.StartsWith('    ') then begin
      Section := Line.Substring(0,Line.IndexOf(':')).Trim;
      if not Field.TryParse(Section) then
        raise Exception.CreateFmt('Unknown section %s',[Line]);
      Line := Line.SubString(Line.IndexOf(':')+1).Trim;
      Mode := _NewSection;
    end;
    case Mode of
      _: if Line.Trim.Length = 0 then continue;
      _NewSection
      : begin
          FSections[OldField].Trim;
          if Line <> '' then
            FSections[Field] := [Line]
          else
            FSections[Field] := [];
          Mode := _InSection;
        end;
      _InSection
      : if (Line = '') then
          FSections[Field].Add('')
        else if Line.StartsWith('      ') then
          FSections[Field].Add(Line.Remove(0,6))
        else if Line.StartsWith('    ') then
          FSections[Field].Add(Line.Remove(0,4))
        else if Line.StartsWith('   ') then
          FSections[Field].Add(Line.Remove(0,3))
        else
          raise Exception.Create('Shouldn''t Happen');
    end;
    OldField := Field;
  end;
  FSections[OldField].Trim;
  Definations := TDefinationDynArray.Create(Format_Definition);
end;

function TComponent.CompName: String;
begin
  Result := Name[0].Trim
    .Replace(' ','')
    .Replace('Components','')
    .Replace('Component','')
    .Replace('/','')
    .Replace('-','');
end;

function TComponent.IsComponentName(const aName: String): Boolean;
var
  lDefination: TDefination;
begin
  Result := False;
  for lDefination in Definations do
    if SameText(aName,lDefination.Name) then exit(True);
end;

function TComponent.Props: TPropDynArray;
var
  lDefination: TDefination;
begin
  Result := [];
  for lDefination in Definations do
    Result := Result + lDefination.Props;
end;

function TComponent.Comps: TCompDynArray;
var
  lDefination: TDefination;
begin
  Result := [];
  for lDefination in Definations do
    Result := Result + lDefination.Comps;
end;

function TComponent.XMLDocs: IXMLDocument;
var
  Doc: TXMLDocument;
  Item: IXMLNode;
begin
  Result := NewXMLDocument;// TXMLDocument.Create(nil);
  Item := Result.AddChild('summary');
  Item.Text := FSections[TComponent.TField.Name].Join;
  Item := Result.AddChild('remarks');
  Item.Text := Lines.Join(#13#10);
end;

{ TComponent.TField_Helper }

function TComponent.TField_Helper.TryParse(const aValue: String): Boolean;
var
  Index: Integer;
begin
  if SameText(aValue,'Examples') then begin
    Self := TComponent.TField.Example;
    Exit(True);
  end;
  if SameText(aValue,'Notation') then begin
    Self := TComponent.TField.Format_Definition;
    Exit(True);
  end;
  Index := GetEnumValue(TypeInfo(TComponent.TField),aValue.Replace(' ','_'));
  Result := Index >= 0;
  if Result then
    Self := TComponent.TField(Index);
end;

function TComponent.TField_Helper.ToString: String;
begin
  Result := GetEnumName(TypeInfo(TComponent.TField),Ord(Self)).Replace('_',' ');
end;

{ TOccurance_Helper }

function TOccurance_Helper.ToString: String;
begin
  Result := GetEnumName(TypeInfo(TOccurance),Ord(Self)).Replace('_',' ');
end;

function TOccurance_Helper.TryParse(const aValue: String): Boolean;
var
  Index: Integer;
begin
  Index := GetEnumValue(TypeInfo(TOccurance),aValue.Replace(' ','_'));
  Result := Index >= 0;
  if Result then
    Self := TOccurance(Index);
end;

constructor TComponent.TDefination_Helper.Create(const Lines: TStringDynArray);
var
  Line: String;
  Mode:(_,InSection,StartSection);
  Index: Integer;
begin
  Mode := _;
  for Line in Lines do begin
    if Mode = InSection then
      if Line.StartsWith('           ') then
        Self[Count-1].Lines.Add(Line.Trim)
      else if Line.Trim <> '' then
        Mode := _;
    if Mode = _ then
      if Line.StartsWith(' ') and (Line[Length(' ')+1] <> ' ') then begin
        Mode := InSection;
        if Count > 0 then
          Self[Count-1].Parse;

        Count := Count + 1;
        Index := Line.IndexOf('=');
        if Index < 0 then
          raise Exception.Create('Shouldn''t happen');
        Self[Count-1].Name := Line.Substring(0,Index).Trim;
        Self[Count-1].Lines.Add(Line.Substring(Index+1).Trim);
      end;
  end;
  if Count > 0 then
    Self[Count-1].Parse;
end;

function TComponent.TDefination_Helper.GetCount: Integer;
begin
  Result := Length(Self);
end;

procedure TComponent.TDefination_Helper.SetCount(const Value: Integer);
begin
  SetLength(Self,Value);
end;

procedure TComponent.TDefination.Parse;
begin
  Parse_Prop;
  Parse_Comp;
end;

procedure TComponent.TDefination.Parse_Prop;
var
  Line: String;
  Mode: (_,InComment,InSection);
  Comment: String;
begin
  Mode := _;
  if not Name.EndsWith('prop') and not Name.EndsWith('props') then exit;
  for Line in Lines do begin
    if Line = '' then continue;
    case Line[Low(Line)] of
      '*','('
      : Continue;
      ')'
      : Break;
      ';'
      : if (Line.Trim = ';') then
          continue
        else case Mode of
          _
          : begin
              Props.Count := Props.Count + 1;
              Mode := InComment;
            end;
          InSection
          : begin
              Props.Count := Props.Count + 1;
              Mode := InComment;
            end;
        end;
    else if Mode = InComment then
      Mode := InSection;
    end;

    case Mode of
      InComment
      : Props[Props.Count-1].AppendComment(Line);
      InSection
      : Props[Props.Count-1].AppendItems(Line.Split(['/']));
    end;

  end;
end;

procedure TComponent.TDefination.Parse_Comp;
var
  Line: String;
  Mode: (_,InComment,InSection);
begin
  Mode := _;
  if not SameText(Name,'component') then exit;
  Line := Lines.Join('').Replace(' ','');
  if Line.Contains('(') then
    Line := Line.SubString(Line.IndexOf('(')+1);
  if Line.Contains(')') then
    SetLength(Line,Line.IndexOf(')'));
  for Line in Line.Split(['/']) do begin
    SetLength(Comps,Length(Comps)+1);
    Comps[High(Comps)] := TNameAnd<TComponent>.Create(Line);
  end;
end;

function TComponent.TPropDynArray_Helper.GetCount: Integer;
begin
  Result := Length(Self);
end;

procedure TComponent.TPropDynArray_Helper.SetCount(const Value: Integer);
begin
  SetLength(Self,Value);
end;

{ TComponent.TProp }

procedure TComponent.TProp.AppendComment(const Line: String);
begin
  Occurances := Occurances + TOccurances.Contains(Line);
  Comments := (Comments + ' '+ Line.Replace(';','').Trim).Trim;
end;

procedure TComponent.TProp.AppendItems(const Items: TArray<String>);
var
  Name: String;
begin
  for Name in Items do begin
    SetLength(NameProps,Length(NameProps)+1);
    NameProps[High(NameProps)] := TNameProp.Create(Name.Trim);
  end;

end;

class function TComponent.TProp.FixName(const aName: String): String;
begin
  Result := Uppercase(aName);
  if SameText(Result,'repeat') or SameText(Result,'class') then
    Result := '&'+Result
  else if SameText(Result,'X-Prop') then
    Result := 'X-'
  else if SameText(Result,'IANA-Prop') then
    Result := 'IANA-'
  else if SameText(Result,'seq') then
    Result := 'SEQUENCE'
  else if SameText(Result,'last-mod') then
    Result := 'LAST-MODIFIED'
  else if SameText(Result,'recurid') then
    Result := 'RECURRENCE-ID'
  else if SameText(Result,'rstatus') then
    Result := 'REQUEST-STATUS'
  else if SameText(Result,'related') then
    Result := 'RELATED-TO'
  else if SameText(Result,'percent') then
    Result := 'PERCENT-COMPLETE';



  Result := Result.Replace('-','_');
end;

constructor TProperty.TParam.Create(const aOccurances: TOccurances; const aName: String; aParameter: TParameter = nil);
begin
  Name := aName;
  Occurances := aOccurances;
  Parameter := aParameter;
end;

class function TProperty.TParam.FixName(const aName: String): String;
begin
  Result := Uppercase(aName).Replace('"','');
  if SameText(Result,'delto') then
    Result := 'DELEGATED-TO'
  else if SameText(Result,'delfrom') then
    Result := 'DELEGATED-FROM'
  else if SameText(Result,'trigrel') then
    Result := 'RELATED'
  else if SameText(Result,'sentby') then
    Result := 'SENT-BY';



  Result := Result.Replace('-','_');
end;

class procedure TProperty.TParam.TryAdd(var Params: TParam.TDynArray; Text: String; Occurances: TOccurances);
var
  Texts: TArray<String>;
begin
  Text := Text.Trim;
  if (Text = '') then exit;
  if (Text = '(') then exit;
  Texts := Text.Split([' ']);
  if Length(Texts) < 2 then exit;
  Text := Texts[1].Replace(')','').Trim;
  if Text.EndsWith('param') then
    SetLength(Text,Text.Length - Length('param'));
  if SameText('other-',Text) then exit;// every thing is other

  SetLength(Params,Length(Params)+1);
  Params[High(Params)] := TParam.Create(Occurances,Text);
end;

var
  RFC5545: TRFC5545;
  UnitName: String;
{ TOccurances_Helper }

class function TOccurances_Helper.Contains(const aValue: String): TOccurances;
var
  Occurance: TOccurance;
begin
  Result := [];
  for Occurance := Low(Occurance) to High(Occurance) do
    if aValue.Contains(Occurance.ToString) then
      Include(Result,Occurance);
end;

constructor TComponent.TNameProp.Create(const aName: String; aProperty: TProperty = nil);
begin
  Name := aName;
  &Property := aProperty;
end;

constructor TNameAnd<T>.Create(const aName: String);
begin
  Name := aName;
  Item := Default(T);
end;

constructor TType.Create(const aLines: TStringDynArray);
var
  Index: Integer;
  Line: String;
  Section: String;
  Field: TType.TField;
  OldField: TType.TField;
  Mode: (_,_NewSection,_InSection);
begin
  Section := 'Name';
  Lines := aLines;
  Lines.Trim;
  Line := aLines[0];
  FSections[TType.TField.Name] := [Line.SubString(Line.IndexOf(' ')).Trim];
  Mode := _;
  Field := Low(Field);
  OldField := Low(OldField);
  for Index := Succ(Low(aLines)) to High(aLines) do begin
    Line := aLines[Index];
    if Line.Contains(':') and (Line.Length > 5) and Line.StartsWith('  ') and not Line.StartsWith('    ') then begin
      Section := Line.Substring(0,Line.IndexOf(':')).Trim;
      if not Field.TryParse(Section) then
        raise Exception.CreateFmt('Unknown section %s',[Line]);
      Line := Line.SubString(Line.IndexOf(':')+1).Trim;
      Mode := _NewSection;
    end;
    case Mode of
      _: if Line.Trim.Length = 0 then continue;
      _NewSection
      : begin
          FSections[OldField].Trim;
          if Line <> '' then
            FSections[Field] := [Line]
          else
            FSections[Field] := [];
          Mode := _InSection;
        end;
      _InSection
      : if (Line = '') then
          FSections[Field].Add('')
        else if Line.StartsWith('      ') then
          FSections[Field].Add(Line.Remove(0,6))
        else if Line.StartsWith('    ') then
          FSections[Field].Add(Line.Remove(0,4))
        else if Line.StartsWith('   ') then
          FSections[Field].Add(Line.Remove(0,3))
        else
          raise Exception.Create('Shouldn''t Happen');
    end;
    OldField := Field;
  end;
  FSections[OldField].Trim;
  Parse;
end;

class procedure TType.AddXMLDoc_Returns(const Types: array of TType; const Indent: String; var Lines: TStringDynArray);
var
  lType: TType;
  Text: String;
begin
  Text := '';
  for lType in Types do
  begin
    if Text = '' then
      Text := lType.TypeName
    else
      Text := Text + ' or ' + lType.TypeName;
  end;
  if Text = '' then exit;
  Lines.Add('%s/// <returns>%s</returns>',[Indent,Text]);
end;

procedure TType.Parse;
var
  Line: String;
  Items: TStringDynArray;
  lIndex: Integer;
begin
  lIndex := -1;
  for Line in Format_Definition do begin
    if line.Trim = '' then continue;
    Items := SplitString(Line,'=');
    if (Items.Count > 1) and (Line.Trim[1] <> ';') and (Length(Items[0].Trim.Split([' '])) = 1) then begin
      Inc(lIndex);
      FDefinations.&Var[lIndex]^.Name := Items[0].Trim;
      FDefinations.&Var[lIndex]^.Lines := [Items[1].Trim];
      Continue;
    end;
    if lIndex < 0 then continue;
    FDefinations.&Var[lIndex].Lines.Add(Line.Trim);
  end;
end;

function TType.TypeName: String;
begin
  Result := Value_Name.Join('');
end;

function TType.TField_Helper.ToString: String;
begin
  Result := GetEnumName(TypeInfo(TProperty.TField),Ord(Self)).Replace('_',' ');
end;

{ TProperty.TField_Helper }

function TType.TField_Helper.TryParse(const aValue: String): Boolean;
var
  Index: Integer;
begin
  Index := GetEnumValue(TypeInfo(TType.TField),aValue.Replace(' ','_'));
  Result := Index >= 0;
  if Result then
    Self := TType.TField(Index);
end;

{ TDynArray_<T> }
function TDynArray_<T>.Add(const aValue: T): Integer;
begin
  Result := Count;
  Insert(Result,aValue);
end;

function TDynArray_<T>.GetCount: Integer;
begin
  Result := Length(Items);
end;

function TDynArray_<T>.GetEnumerator: TEnumorator;
begin
  Result.Items := Items;
  Result.CurrentIndex := -1;
end;

function TDynArray_<T>.GetItem(Index: Integer): T;
begin
  Result := Items[Index];
end;

function TDynArray_<T>.GetVar(Index: Integer): P;
begin
  if Index >= Count then
    Count := Index + 1;
  Result := @Items[Index];
end;

procedure TDynArray_<T>.Insert(Index: Integer; const aValue: T);
begin
  System.Insert(aValue,Items,Index);
end;

procedure TDynArray_<T>.SetCount(const Value: Integer);
begin
  SetLength(Items,Value);
end;

procedure TDynArray_<T>.SetItem(Index: Integer; const Value: T);
begin
  Items[Index] := Value;
end;

procedure TType.TList.Add(Item: TType);
begin
  AddOrSetValue(Item.TypeName,Item);
end;

function TType.TList.ValueNameTo(const aName: String): TDynArray_<TType>;
var
  lType: TType;
  lPair: TList.TPair;
begin
  Result.Items := [];
  if TryGetValue(aName,lType) then
    Result.Items := [lType]
  else for lPair in Self do
    if Pos(lPair.Key,aName) > 0 then
      Result.Add(lPair.Value);
end;

{ TDynArray_<T>.TEnumorator }

function TDynArray_<T>.TEnumorator.GetCurrent: T;
begin
  Result := Items[CurrentIndex];
end;

function TDynArray_<T>.TEnumorator.MoveNext: Boolean;
begin
  Result := CurrentIndex < High(Items);
  if Result then
    Inc(CurrentIndex);
end;

begin
  DefaultDOMVendor := sOmniXmlVendor;
  try
    UnitName := 'iCalendarAPI';
    Writeln('Retriving Specification');
    RFC5545 := TRFC5545.Create;
    Writeln(RFC5545.Doc.Count);
    Writeln(RFC5545.Parameters[0].Lines.Join(#13#10));
    RFC5545.Doc.Clear;
    with TJsonSerializer.Create do try
      TFile.WriteAllText('xxx.json', Serialize<TRFC5545>(RFC5545));
      ShellExecute(0, 'open', 'xxx.json', nil, nil, SW_SHOWNORMAL);
    finally
      Free;
    end;
    RFC5545.GenerateDelphi(UnitName).SaveToFile(UnitName+'.pas');
    UnitName := UnitName + '.pas';
      ShellExecute(0, 'open', pChar(UnitName), nil, nil, SW_SHOWNORMAL);
  except
    on E: Exception do begin
      Writeln(E.ClassName, ': ', E.Message);
      Readln;
    end;
  end;
end.

