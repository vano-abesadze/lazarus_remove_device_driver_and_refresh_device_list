unit device_helper;

interface

uses
  Windows,Classes,
  SysUtils;

//function EjectUSB(const DriveLetter: char): boolean;
//function remove_device(const dev_guid: string;name:string): boolean;
function remove_device_(name:string): boolean;
function refresh: boolean;


implementation

type
  DEVICE_TYPE = DWORD;
  _DEVINST = DWORD;
  HDEVINFO = Pointer;
  PPNP_VETO_TYPE = ^PNP_VETO_TYPE;
  PNP_VETO_TYPE = DWORD;
  RETURN_TYPE = DWORD;
  CONFIGRET = RETURN_TYPE;
  DEVINSTID = PWideChar;

const
  PNP_VetoTypeUnknown = 0;   // Name is unspecified

type
  PSPDeviceInterfaceDetailDataA = ^TSPDeviceInterfaceDetailDataA;
  SP_DEVICE_INTERFACE_DETAIL_DATA_A = packed record
    cbSize: DWORD;
    DevicePath: array [0..ANYSIZE_ARRAY - 1] of AnsiChar;
  end;
  TSPDeviceInterfaceDetailDataA = SP_DEVICE_INTERFACE_DETAIL_DATA_A;
  TSPDeviceInterfaceDetailData = TSPDeviceInterfaceDetailDataA;
  PSPDeviceInterfaceDetailData = PSPDeviceInterfaceDetailDataA;

  PSPDeviceInterfaceData = ^TSPDeviceInterfaceData;
  SP_DEVICE_INTERFACE_DATA = packed record
    cbSize: DWORD;
    InterfaceClassGuid: TGUID;
    Flags: DWORD;
    Reserved: ULONG_PTR;
  end;
  TSPDeviceInterfaceData = SP_DEVICE_INTERFACE_DATA;

  PSPDevInfoData = ^TSPDevInfoData;
  SP_DEVINFO_DATA = packed record
    cbSize: DWORD;
    ClassGuid: TGUID;
    DevInst: DWORD; // DEVINST handle
    Reserved: ULONG_PTR;
  end;
  TSPDevInfoData = SP_DEVINFO_DATA;

  _STORAGE_DEVICE_NUMBER = record
    DeviceType: DEVICE_TYPE;
    DeviceNumber: DWORD;
    PartitionNumber: DWORD;
  end;
  STORAGE_DEVICE_NUMBER = _STORAGE_DEVICE_NUMBER;

const

  CR_NO_SUCH_VALUE            = $00000025;
  CM_LOCATE_DEVNODE_NORMAL       = $00000000;
  SPDRP_FRIENDLYNAME                = $0000000C;
  SPDRP_DEVICEDESC                  = $00000000; // DeviceDesc (R/W)
  CR_SUCCESS = $00000000;
  DIGCF_PRESENT = $00000002;
  DIGCF_DEVICEINTERFACE = $00000010;
  FILE_DEVICE_MASS_STORAGE = $0000002d;
  FILE_ANY_ACCESS = 0;
  METHOD_BUFFERED = 0;
  IOCTL_STORAGE_BASE = FILE_DEVICE_MASS_STORAGE;
  IOCTL_STORAGE_GET_DEVICE_NUMBER =
    (IOCTL_STORAGE_BASE shl 16) or (FILE_ANY_ACCESS shl 14) or
    ($0420 shl 2) or (METHOD_BUFFERED);

const
  GUID_DEVINTERFACE_DISK: TGUID = (
    D1: $53f56307; D2: $b6bf; D3: $11d0; D4: ($94, $f2, $00, $a0, $c9, $1e, $fb, $8b));
  GUID_DEVINTERFACE_CDROM: TGUID = (
    D1: $53f56308; D2: $b6bf; D3: $11d0; D4: ($94, $f2, $00, $a0, $c9, $1e, $fb, $8b));
  GUID_DEVINTERFACE_FLOPPY: TGUID = (
    D1: $53f56311; D2: $b6bf; D3: $11d0; D4: ($94, $f2, $00, $a0, $c9, $1e, $fb, $8b));

type
  TCM_Get_Parent = function(var dnDevInstParent: _DEVINST; dnDevInst: _DEVINST;
    ulFlags: ULONG): CONFIGRET; stdcall;
  TCM_Request_Device_Eject = function(dnDevInst: _DEVINST;
    pVetoType: PPNP_VETO_TYPE;     // OPTIONAL
    pszVetoName: PTSTR;            // OPTIONAL
    ulNameLength: ULONG; ulFlags: ULONG): CONFIGRET; stdcall;
  TSetupDiGetClassDevs = function(ClassGuid: PGUID; const aEnumerator: PTSTR;
    hwndParent: HWND; Flags: DWORD): HDEVINFO; stdcall;
  TSetupDiEnumDeviceInterfaces = function(DeviceInfoSet: HDEVINFO;
    DeviceInfoData: PSPDevInfoData; const InterfaceClassGuid: TGUID;
    MemberIndex: DWORD; var DeviceInterfaceData: TSPDeviceInterfaceData): BOOL; stdcall;
  TSetupDiGetDeviceInterfaceDetail = function(DeviceInfoSet: HDEVINFO;
    DeviceInterfaceData: PSPDeviceInterfaceData;
    DeviceInterfaceDetailData: PSPDeviceInterfaceDetailData;
    DeviceInterfaceDetailDataSize: DWORD; var RequiredSize: DWORD;
    Device: PSPDevInfoData): BOOL; stdcall;
  TSetupDiDestroyDeviceInfoList = function(DeviceInfoSet: HDEVINFO): BOOL; stdcall;

  TSetupDiRemoveDevice = function(DeviceInfoSet: HDEVINFO;    var DeviceInfoData: TSPDevInfoData): LongBool; stdcall;
  TSetupDiEnumDeviceInfo = function(DeviceInfoSet: HDEVINFO;  MemberIndex: DWORD; var DeviceInfoData: TSPDevInfoData): BOOL; stdcall;
  TSetupDiGetDeviceRegistryProperty= function(DeviceInfoSet: HDEVINFO;
    const DeviceInfoData: TSPDevInfoData; Property_: DWORD;
    var PropertyRegDataType: DWORD; PropertyBuffer: PBYTE; PropertyBufferSize: DWORD;
    var RequiredSize: DWORD): BOOL; stdcall;

  TCM_Reenumerate_DevNode = function(dnDevInst: _DEVINST;
    ulFlags: ULONG): CONFIGRET; stdcall;

   TCM_Locate_DevNode = function(var dnDevInst: _DEVINST;    pDeviceID: DEVINSTID;     ulFlags: ULONG): CONFIGRET; stdcall;
   TCM_Enumerate_Classes = function(ulClassIndex: ULONG; var ClassGuid: TGUID; ulFlags: ULONG): CONFIGRET; stdcall;
   TSetupDiGetClassDescription = function (var ClassGuid: TGUID; ClassDescription: PAnsiChar;  ClassDescriptionSize: DWORD; var RequiredSize: DWORD): BOOL; stdcall;



   var
       CM_Locate_DevNode:TCM_Locate_DevNode;
       CM_Reenumerate_DevNode:TCM_Reenumerate_DevNode;


   function refresh:boolean;
     const
    CfgMgrDllName = 'cfgmgr32.dll';
    SetupApiModuleName = 'SetupApi.dll';

   var
       retval: CONFIGRET;
       DEVINST:_DEVINST;
           CfgMgrApiLib: HINST;
    SetupApiLib: HINST;

   begin
     CfgMgrApiLib := LoadLibrary(CfgMgrDllName);
     SetupApiLib := LoadLibrary(SetupApiModuleName);
     try
      if (CfgMgrApiLib <> 0) and (SetupApiLib <> 0) then
      begin
        pointer(CM_Locate_DevNode):=GetProcAddress(CfgMgrApiLib,'CM_Locate_DevNodeA');
        retval := CM_Locate_DevNode(DEVINST, nil, CM_LOCATE_DEVNODE_NORMAL);
        if (retval = CR_SUCCESS) then
        begin
          retval := CM_Reenumerate_DevNode(DEVINST, 0);
        end;

      end;
     finally
      if CfgMgrApiLib <> 0 then FreeLibrary(CfgMgrApiLib);
      if SetupApiLib <> 0 then FreeLibrary(SetupApiLib);
    end;




end;





   function remove_device_(name:string): boolean;
  const
    CfgMgrDllName = 'cfgmgr32.dll';
    SetupApiModuleName = 'SetupApi.dll';
  var

      retval: CONFIGRET;

    CfgMgrApiLib: HINST;
    SetupApiLib: HINST;

    CM_Get_Parent: TCM_Get_Parent;
    CM_Request_Device_Eject: TCM_Request_Device_Eject;
    SetupDiGetClassDevs: TSetupDiGetClassDevs;
    SetupDiEnumDeviceInterfaces: TSetupDiEnumDeviceInterfaces;
    SetupDiGetDeviceInterfaceDetail: TSetupDiGetDeviceInterfaceDetail;
    SetupDiDestroyDeviceInfoList: TSetupDiDestroyDeviceInfoList;
    SetupDiRemoveDevice:TSetupDiRemoveDevice;
    SetupDiEnumDeviceInfo:TSetupDiEnumDeviceInfo;
    SetupDiGetDeviceRegistryProperty:TSetupDiGetDeviceRegistryProperty;


    CM_Enumerate_Classes:TCM_Enumerate_Classes;
    SetupDiGetClassDescription:TSetupDiGetClassDescription;

    DevData: TSPDevInfoData;

    StorageGUID: TGUID;
    hDevInfo: Pointer; //HDEVINFO;
    dwIndex: DWORD;
    pspdidd: PSPDeviceInterfaceDetailData;
      spdid: SP_DEVICE_INTERFACE_DATA;
      spdd: SP_DEVINFO_DATA;
      dwSize: DWORD;
      hDrive: THandle;
      sdn: STORAGE_DEVICE_NUMBER;
      res: BOOL;
      dwBytesReturned: DWORD;
      DeviceNumber: LONG;
      DEVINST:_DEVINST;

      var DeviceInterfaceData: TSPDeviceInterfaceData;

     s:string;
          _SPDevInfoData :array of TSPDevInfoData;
  _HDEVINFO: array of Pointer;
  dd:integer;

  _SP:TSPDevInfoData;
  _HD:Pointer;


  BytesReturned: DWORD;
  RegDataType: DWORD;
  //Buffer: array [0..256] of TCHAR;
  Buffer: array [0..256] of char;
  List: TStringList;
  i:integer;
  GUID: PGUID;
  Ret: CONFIGRET;
  BufSize: DWORD;



  begin
    Result := False;
    CfgMgrApiLib := LoadLibrary(CfgMgrDllName);
    SetupApiLib := LoadLibrary(SetupApiModuleName);

    try
      if (CfgMgrApiLib <> 0) and (SetupApiLib <> 0) then
      begin
        pointer(CM_Get_Parent) := GetProcAddress(CfgMgrApiLib, 'CM_Get_Parent');
        pointer(CM_Request_Device_Eject) := GetProcAddress(SetupApiLib, 'CM_Request_Device_EjectA');
        pointer(SetupDiGetClassDevs) := GetProcAddress(SetupApiLib, 'SetupDiGetClassDevsA');
        pointer(SetupDiEnumDeviceInterfaces) := GetProcAddress(SetupApiLib, 'SetupDiEnumDeviceInterfaces');
        pointer(SetupDiGetDeviceInterfaceDetail) := GetProcAddress(SetupApiLib, 'SetupDiGetDeviceInterfaceDetailA');
        pointer(SetupDiDestroyDeviceInfoList) := GetProcAddress(SetupApiLib, 'SetupDiDestroyDeviceInfoList');
        pointer(SetupDiRemoveDevice) := GetProcAddress(SetupApiLib, 'SetupDiRemoveDevice');
        pointer(SetupDiEnumDeviceInfo):= GetProcAddress(SetupApiLib, 'SetupDiEnumDeviceInfo');
        pointer(SetupDiGetDeviceRegistryProperty):=GetProcAddress(SetupApiLib, 'SetupDiGetDeviceRegistryPropertyA');
        pointer(CM_Reenumerate_DevNode):=GetProcAddress(CfgMgrApiLib,'CM_Reenumerate_DevNode');
        pointer(CM_Locate_DevNode):=GetProcAddress(CfgMgrApiLib,'CM_Locate_DevNodeA');
        pointer(CM_Enumerate_Classes):=GetProcAddress(CfgMgrApiLib,'CM_Enumerate_Classes');
        pointer(SetupDiGetClassDescription):=GetProcAddress(SetupApiLib,'SetupDiGetClassDescriptionA');


        //deviceInfoData = GetDeviceInfo(deviceInfoSet, deviceId);



        List := TStringList.Create;
        I := 0;
        repeat
          GetMem(GUID, SizeOf(TGUID));
          Ret := CM_Enumerate_Classes(I, GUID^, 0);
          if Ret <> CR_NO_SUCH_VALUE then
          begin
            SetupDiGetClassDescription(GUID^, @Buffer[0], Length(Buffer), BufSize);
            List.AddObject(PTSTR(@Buffer[0]), TObject(GUID));
          end;
          Inc(I);
        until Ret = CR_NO_SUCH_VALUE;


        List.Sorted := True;
        for I := 0 to List.Count - 1 do
        begin

        GUID := PGUID(List.Objects[I]);

                          //////////////////////////////////

                          //StorageGUID:=StringToGUID(dev_guid);
                          StorageGUID:=GUID^;



                        HDEVINFO := SetupDiGetClassDevs(@StorageGUID, nil, 0, 0);



                        //hDevInfo := SetupDiGetClassDevs(@StorageGUID, nil, 0, DIGCF_PRESENT or DIGCF_DEVICEINTERFACE);
                      if (NativeUInt(hDevInfo) <> INVALID_HANDLE_VALUE) then
                      try
                          // Retrieve a context structure for a device interface of a device information set
                          dwIndex := 0;
                          //PSP_DEVICE_INTERFACE_DETAIL_DATA pspdidd = (PSP_DEVICE_INTERFACE_DETAIL_DATA)Buf;
                          spdid.cbSize := SizeOf(spdid);


                          DeviceInterfaceData.cbSize := SizeOf(TSPDeviceInterfaceData);
                          DevData.cbSize := SizeOf(DevData);

                          while True do
                          begin
                              //res := SetupDiEnumDeviceInterfaces(hDevInfo, nil, StorageGUID, dwIndex, spdid);
                              res:=SetupDiEnumDeviceInfo(HDEVINFO,dwIndex,DevData);
                              if not res then break;

                              dwSize := 0;

                              SetLength(_SPDevInfoData,dwIndex+1);
                            _SPDevInfoData[dwIndex]:=DevData;
                            _SPDevInfoData[dwIndex].cbSize:=DevData.cbSize;

                             SetLength(_HDEVINFO,dwIndex+1);
                            _HDEVINFO[dwIndex]:=HDEVINFO;
                            inc(dwIndex);

                              _SP:=DevData;
                              _HD:=HDEVINFO;


                              BytesReturned := 0;
                              RegDataType := 0;
                              Buffer[0] := #0;

                              SetupDiGetDeviceRegistryProperty(HDEVINFO, DevData, SPDRP_FRIENDLYNAME,RegDataType, PByte(@Buffer[0]), SizeOf(Buffer), BytesReturned);
                              s:=Buffer;

                              if S = '' then
                              begin
                                  BytesReturned := 0;
                                  RegDataType := 0;
                                  Buffer[0] := #0;

                                    SetupDiGetDeviceRegistryProperty(HDEVINFO, DevData, SPDRP_DEVICEDESC,RegDataType, PByte(@Buffer[0]), SizeOf(Buffer), BytesReturned);
                                  S := Buffer;

                              end;

                              if S=name then
                              begin
                                 SetupDiRemoveDevice(HDEVINFO,DevData);
                                 WriteLn('aaaaaaaaaa');

                                 //exit;
                              end;


                          end;


                          /////////////////////////////////////


                      finally
                      SetupDiDestroyDeviceInfoList(HDEVINFO);

                      end;


        end;

          FreeMem(GUID);
          List.Objects[I] := nil;


         List.Free;


        //retval := CM_Locate_DevNode(DEVINST, nil, CM_LOCATE_DEVNODE_NORMAL);
        //if (retval = CR_SUCCESS) then
        //begin
        //  retval := CM_Reenumerate_DevNode(DEVINST, 0);
        //end;



    end;




        //Result := ReallyEjectUSB(DriveLetter);

    finally
      if CfgMgrApiLib <> 0 then FreeLibrary(CfgMgrApiLib);
      if SetupApiLib <> 0 then FreeLibrary(SetupApiLib);
    end;

  end;









  //function remove_device(const dev_guid: string;name:string): boolean;
  //const
  //  CfgMgrDllName = 'cfgmgr32.dll';
  //  SetupApiModuleName = 'SetupApi.dll';
  //var
  //
  //    retval: CONFIGRET;
  //
  //  CfgMgrApiLib: HINST;
  //  SetupApiLib: HINST;
  //
  //  CM_Get_Parent: TCM_Get_Parent;
  //  CM_Request_Device_Eject: TCM_Request_Device_Eject;
  //  SetupDiGetClassDevs: TSetupDiGetClassDevs;
  //  SetupDiEnumDeviceInterfaces: TSetupDiEnumDeviceInterfaces;
  //  SetupDiGetDeviceInterfaceDetail: TSetupDiGetDeviceInterfaceDetail;
  //  SetupDiDestroyDeviceInfoList: TSetupDiDestroyDeviceInfoList;
  //  SetupDiRemoveDevice:TSetupDiRemoveDevice;
  //  SetupDiEnumDeviceInfo:TSetupDiEnumDeviceInfo;
  //  SetupDiGetDeviceRegistryProperty:TSetupDiGetDeviceRegistryProperty;
  //  CM_Reenumerate_DevNode:TCM_Reenumerate_DevNode;
  //  CM_Locate_DevNode:TCM_Locate_DevNode;
  //
  //  DevData: TSPDevInfoData;
  //
  //  StorageGUID: TGUID;
  //  hDevInfo: Pointer; //HDEVINFO;
  //  dwIndex: DWORD;
  //  pspdidd: PSPDeviceInterfaceDetailData;
  //    spdid: SP_DEVICE_INTERFACE_DATA;
  //    spdd: SP_DEVINFO_DATA;
  //    dwSize: DWORD;
  //    hDrive: THandle;
  //    sdn: STORAGE_DEVICE_NUMBER;
  //    res: BOOL;
  //    dwBytesReturned: DWORD;
  //    DeviceNumber: LONG;
  //    DEVINST:_DEVINST;
  //
  //    var DeviceInterfaceData: TSPDeviceInterfaceData;
  //
  //   s:string;
  //        _SPDevInfoData :array of TSPDevInfoData;
  //_HDEVINFO: array of Pointer;
  //dd:integer;
  //
  //_SP:TSPDevInfoData;
  //_HD:Pointer;
  //
  //
  //BytesReturned: DWORD;
  //RegDataType: DWORD;
  ////Buffer: array [0..256] of TCHAR;
  //Buffer: array [0..256] of char;
  //
  //begin
  //  Result := False;
  //  CfgMgrApiLib := LoadLibrary(CfgMgrDllName);
  //  SetupApiLib := LoadLibrary(SetupApiModuleName);
  //
  //  try
  //    if (CfgMgrApiLib <> 0) and (SetupApiLib <> 0) then
  //    begin
  //      pointer(CM_Get_Parent) := GetProcAddress(CfgMgrApiLib, 'CM_Get_Parent');
  //      pointer(CM_Request_Device_Eject) := GetProcAddress(SetupApiLib, 'CM_Request_Device_EjectA');
  //      pointer(SetupDiGetClassDevs) := GetProcAddress(SetupApiLib, 'SetupDiGetClassDevsA');
  //      pointer(SetupDiEnumDeviceInterfaces) := GetProcAddress(SetupApiLib, 'SetupDiEnumDeviceInterfaces');
  //      pointer(SetupDiGetDeviceInterfaceDetail) := GetProcAddress(SetupApiLib, 'SetupDiGetDeviceInterfaceDetailA');
  //      pointer(SetupDiDestroyDeviceInfoList) := GetProcAddress(SetupApiLib, 'SetupDiDestroyDeviceInfoList');
  //      pointer(SetupDiRemoveDevice) := GetProcAddress(SetupApiLib, 'SetupDiRemoveDevice');
  //      pointer(SetupDiEnumDeviceInfo):= GetProcAddress(SetupApiLib, 'SetupDiEnumDeviceInfo');
  //      pointer(SetupDiGetDeviceRegistryProperty):=GetProcAddress(SetupApiLib, 'SetupDiGetDeviceRegistryPropertyA');
  //      pointer(CM_Reenumerate_DevNode):=GetProcAddress(CfgMgrApiLib,'CM_Reenumerate_DevNode');
  //      pointer(CM_Locate_DevNode):=GetProcAddress(CfgMgrApiLib,'CM_Locate_DevNodeA');
  //      //deviceInfoData = GetDeviceInfo(deviceInfoSet, deviceId);
  //
  //      StorageGUID:=StringToGUID(dev_guid);
  //
  //
  //
  //      HDEVINFO := SetupDiGetClassDevs(@StorageGUID, nil, 0, 0);
  //
  //
  //
  //      //hDevInfo := SetupDiGetClassDevs(@StorageGUID, nil, 0, DIGCF_PRESENT or DIGCF_DEVICEINTERFACE);
  //    if (NativeUInt(hDevInfo) <> INVALID_HANDLE_VALUE) then
  //      try
  //        // Retrieve a context structure for a device interface of a device information set
  //        dwIndex := 0;
  //        //PSP_DEVICE_INTERFACE_DETAIL_DATA pspdidd = (PSP_DEVICE_INTERFACE_DETAIL_DATA)Buf;
  //        spdid.cbSize := SizeOf(spdid);
  //
  //
  //        DeviceInterfaceData.cbSize := SizeOf(TSPDeviceInterfaceData);
  //        DevData.cbSize := SizeOf(DevData);
  //
  //        while True do
  //        begin
  //          //res := SetupDiEnumDeviceInterfaces(hDevInfo, nil, StorageGUID, dwIndex, spdid);
  //          res:=SetupDiEnumDeviceInfo(HDEVINFO,dwIndex,DevData);
  //          if not res then break;
  //
  //          dwSize := 0;
  //
  //          SetLength(_SPDevInfoData,dwIndex+1);
  //        _SPDevInfoData[dwIndex]:=DevData;
  //        _SPDevInfoData[dwIndex].cbSize:=DevData.cbSize;
  //
  //         SetLength(_HDEVINFO,dwIndex+1);
  //        _HDEVINFO[dwIndex]:=HDEVINFO;
  //        inc(dwIndex);
  //
  //          _SP:=DevData;
  //          _HD:=HDEVINFO;
  //
  //
  //          BytesReturned := 0;
  //          RegDataType := 0;
  //          Buffer[0] := #0;
  //
  //          SetupDiGetDeviceRegistryProperty(HDEVINFO, DevData, SPDRP_FRIENDLYNAME,RegDataType, PByte(@Buffer[0]), SizeOf(Buffer), BytesReturned);
  //          s:=Buffer;
  //
  //          if S = '' then
  //          begin
  //            BytesReturned := 0;
  //          RegDataType := 0;
  //          Buffer[0] := #0;
  //
  //            SetupDiGetDeviceRegistryProperty(HDEVINFO, DevData, SPDRP_DEVICEDESC,RegDataType, PByte(@Buffer[0]), SizeOf(Buffer), BytesReturned);
  //          S := Buffer;
  //
  //          end;
  //
  //          if S=name then
  //          begin
  //             SetupDiRemoveDevice(HDEVINFO,DevData);
  //          end;
  //
  //
  //        end;
  //
  //
  //
  //      finally
  //        SetupDiDestroyDeviceInfoList(HDEVINFO);
  //        retval := CM_Locate_DevNode(DEVINST, nil, CM_LOCATE_DEVNODE_NORMAL);
  //        if (retval = CR_SUCCESS) then
  //        begin
  //          retval := CM_Reenumerate_DevNode(DEVINST, 0);
  //        end;
  //      end;
  //  end;
  //
  //
  //
  //      //Result := ReallyEjectUSB(DriveLetter);
  //
  //  finally
  //    if CfgMgrApiLib <> 0 then FreeLibrary(CfgMgrApiLib);
  //    if SetupApiLib <> 0 then FreeLibrary(SetupApiLib);
  //  end;
  //
  //end;      if (retval = CR_SUCCESS) then
  //        begin
  //          retval := CM_Reenumerate_DevNode(DEVINST, 0);
  //        end;
  //      end;
  //  end;
  //
  //
  //
  //      //Result := ReallyEjectUSB(DriveLetter);
  //
  //  finally
  //    if CfgMgrApiLib <> 0 then FreeLibrary(CfgMgrApiLib);
  //    if SetupApiLib <> 0 then FreeLibrary(SetupApiLib);
  //  end;
  //
  //end;











  //function EjectUSB(const DriveLetter: char): boolean;
  //const
  //  CfgMgrDllName = 'cfgmgr32.dll';
  //  SetupApiModuleName = 'SetupApi.dll';
  //var
  //  CM_Get_Parent: TCM_Get_Parent;
  //  CM_Request_Device_Eject: TCM_Request_Device_Eject;
  //  SetupDiGetClassDevs: TSetupDiGetClassDevs;
  //  SetupDiEnumDeviceInterfaces: TSetupDiEnumDeviceInterfaces;
  //  SetupDiGetDeviceInterfaceDetail: TSetupDiGetDeviceInterfaceDetail;
  //  SetupDiDestroyDeviceInfoList: TSetupDiDestroyDeviceInfoList;
  //var
  //  CfgMgrApiLib: HINST;
  //  SetupApiLib: HINST;
  //
  //  function GetDrivesDevInstByDeviceNumber(DeviceNumber: LONG; DriveType: UINT; szDosDeviceName: PChar): _DEVINST;
  //  var
  //    StorageGUID: TGUID;
  //    IsFloppy: boolean;
  //    hDevInfo: Pointer; //HDEVINFO;
  //    dwIndex: DWORD;
  //    res: BOOL;
  //    pspdidd: PSPDeviceInterfaceDetailData;
  //    spdid: SP_DEVICE_INTERFACE_DATA;
  //    spdd: SP_DEVINFO_DATA;
  //    dwSize: DWORD;
  //    hDrive: THandle;
  //    sdn: STORAGE_DEVICE_NUMBER;
  //    dwBytesReturned: DWORD;
  //  begin
  //    Result := 0;
  //
  //    IsFloppy := pos('\\Floppy', szDosDeviceName) > 0; // who knows a better way?
  //    case DriveType of
  //      DRIVE_REMOVABLE:
  //        if (IsFloppy) then
  //          StorageGUID := GUID_DEVINTERFACE_FLOPPY
  //        else
  //          StorageGUID := GUID_DEVINTERFACE_DISK;
  //      DRIVE_FIXED: StorageGUID := GUID_DEVINTERFACE_DISK;
  //      DRIVE_CDROM: StorageGUID := GUID_DEVINTERFACE_CDROM;
  //      else
  //        exit
  //    end;
  //
  //    // Get device interface info set handle for all devices attached to system
  //    hDevInfo := SetupDiGetClassDevs(@StorageGUID, nil, 0, DIGCF_PRESENT or DIGCF_DEVICEINTERFACE);
  //    if (NativeUInt(hDevInfo) <> INVALID_HANDLE_VALUE) then
  //      try
  //        // Retrieve a context structure for a device interface of a device information set
  //        dwIndex := 0;
  //        //PSP_DEVICE_INTERFACE_DETAIL_DATA pspdidd = (PSP_DEVICE_INTERFACE_DETAIL_DATA)Buf;
  //        spdid.cbSize := SizeOf(spdid);
  //
  //        while True do
  //        begin
  //          res := SetupDiEnumDeviceInterfaces(hDevInfo, nil, StorageGUID, dwIndex, spdid);
  //          if not res then break;
  //
  //          dwSize := 0;
  //          SetupDiGetDeviceInterfaceDetail(hDevInfo, @spdid, nil, 0, dwSize, nil);
  //          // check the buffer size
  //
  //          if (dwSize <> 0) then
  //          begin
  //            pspdidd := AllocMem(dwSize);
  //            try
  //              pspdidd^.cbSize := SizeOf(TSPDeviceInterfaceDetailData);
  //              ZeroMemory(@spdd, sizeof(spdd));
  //              spdd.cbSize := SizeOf(spdd);
  //              res := SetupDiGetDeviceInterfaceDetail(hDevInfo, @spdid, pspdidd, dwSize, dwSize, @spdd);
  //              if res then
  //              begin
  //                // open the disk or cdrom or floppy
  //                hDrive := CreateFile(pspdidd^.DevicePath, 0, FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0);
  //                if (hDrive <> INVALID_HANDLE_VALUE) then
  //                  try
  //                    // get its device number
  //                    dwBytesReturned := 0;
  //                    res := DeviceIoControl(hDrive, IOCTL_STORAGE_GET_DEVICE_NUMBER, nil, 0, @sdn, sizeof(sdn), dwBytesReturned, nil);
  //                    if res then
  //                    begin
  //                      if (DeviceNumber = sdn.DeviceNumber) then
  //                      begin  // match the given device number with the one of the current device
  //                        Result := spdd.DevInst;
  //                        exit;
  //                      end;
  //                    end;
  //                  finally
  //                    CloseHandle(hDrive);
  //                  end;
  //              end;
  //            finally
  //              FreeMem(pspdidd);
  //            end;
  //          end;
  //          Inc(dwIndex);
  //        end;
  //      finally
  //        SetupDiDestroyDeviceInfoList(hDevInfo);
  //      end;
  //  end;
  //
  //  function ReallyEjectUSB(const DriveLetter: char): boolean;
  //  var
  //    szRootPath, szDevicePath: string;
  //    szVolumeAccessPath: string;
  //    hVolume: THandle;
  //    DeviceNumber: LONG;
  //    sdn: STORAGE_DEVICE_NUMBER;
  //    dwBytesReturned: DWORD;
  //    res: BOOL;
  //    resCM: cardinal;
  //    DriveType: UINT;
  //    szDosDeviceName: array [0..MAX_PATH - 1] of char;
  //    DevInst: _DEVINST;
  //    VetoType: PNP_VETO_TYPE;
  //    VetoName: array [0..MAX_PATH - 1] of WCHAR;
  //    DevInstParent: _DEVINST;
  //    tries: integer;
  //  begin
  //    Result := False;
  //
  //    szRootPath := DriveLetter + ':\';
  //    szDevicePath := DriveLetter + ':';
  //    szVolumeAccessPath := Format('\\.\%s:', [DriveLetter]);
  //
  //    DeviceNumber := -1;
  //    // open the storage volume
  //    hVolume := CreateFile(PChar(szVolumeAccessPath), 0, FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0);
  //    if (hVolume <> INVALID_HANDLE_VALUE) then
  //      try
  //        //get the volume's device number
  //        dwBytesReturned := 0;
  //        res := DeviceIoControl(hVolume, IOCTL_STORAGE_GET_DEVICE_NUMBER, nil, 0, @sdn, SizeOf(sdn), dwBytesReturned, nil);
  //        if res then DeviceNumber := sdn.DeviceNumber;
  //      finally
  //        CloseHandle(hVolume);
  //      end;
  //    if DeviceNumber = -1 then exit;
  //
  //    // get the drive type which is required to match the device numbers correctely
  //    DriveType := GetDriveType(PChar(szRootPath));
  //
  //    // get the dos device name (like \device\floppy0) to decide if it's a floppy or not - who knows a better way?
  //    QueryDosDevice(PChar(szDevicePath), szDosDeviceName, MAX_PATH);
  //
  //    // get the device instance handle of the storage volume by means of a SetupDi enum and matching the device number
  //    DevInst := GetDrivesDevInstByDeviceNumber(DeviceNumber, DriveType, szDosDeviceName);
  //
  //    if (DevInst = 0) then exit;
  //
  //    VetoType := PNP_VetoTypeUnknown;
  //
  //    // get drives's parent, e.g. the USB bridge, the SATA port, an IDE channel with two drives!
  //    DevInstParent := 0;
  //    resCM := CM_Get_Parent(DevInstParent, DevInst, 0);
  //
  //    for tries := 0 to 3 do // sometimes we need some tries...
  //    begin
  //      FillChar(VetoName[0], SizeOf(VetoName), 0);
  //
  //      // CM_Query_And_Remove_SubTree doesn't work for restricted users
  //      //resCM = CM_Query_And_Remove_SubTree(DevInstParent, &VetoType, VetoNameW, MAX_PATH, CM_REMOVE_NO_RESTART); // CM_Query_And_Remove_SubTreeA is not implemented under W2K!
  //      //resCM = CM_Query_And_Remove_SubTree(DevInstParent, NULL, NULL, 0, CM_REMOVE_NO_RESTART);  // with messagebox (W2K, Vista) or balloon (XP)
  //
  //      resCM := CM_Request_Device_Eject(DevInstParent, @VetoType, @VetoName[0], Length(VetoName), 0);
  //      resCM := CM_Request_Device_Eject(DevInstParent, nil, nil, 0, 0);
  //      // optional -> shows messagebox (W2K, Vista) or balloon (XP)
  //
  //      Result := (resCM = CR_SUCCESS) and (VetoType = PNP_VetoTypeUnknown);
  //      if Result then break;
  //
  //      Sleep(500); // required to give the next tries a chance!
  //    end;
  //
  //  end;
  //
  //begin
  //  Result := False;
  //  CfgMgrApiLib := LoadLibrary(CfgMgrDllName);
  //  SetupApiLib := LoadLibrary(SetupApiModuleName);
  //  try
  //    if (CfgMgrApiLib <> 0) and (SetupApiLib <> 0) then
  //    begin
  //      pointer(CM_Get_Parent) := GetProcAddress(CfgMgrApiLib, 'CM_Get_Parent');
  //      pointer(CM_Request_Device_Eject) := GetProcAddress(SetupApiLib, 'CM_Request_Device_EjectA');
  //      pointer(SetupDiGetClassDevs) := GetProcAddress(SetupApiLib, 'SetupDiGetClassDevsA');
  //      pointer(SetupDiEnumDeviceInterfaces) := GetProcAddress(SetupApiLib, 'SetupDiEnumDeviceInterfaces');
  //      pointer(SetupDiGetDeviceInterfaceDetail) := GetProcAddress(SetupApiLib, 'SetupDiGetDeviceInterfaceDetailA');
  //      pointer(SetupDiDestroyDeviceInfoList) := GetProcAddress(SetupApiLib, 'SetupDiDestroyDeviceInfoList');
  //      Result := ReallyEjectUSB(DriveLetter);
  //    end;
  //  finally
  //    if CfgMgrApiLib <> 0 then FreeLibrary(CfgMgrApiLib);
  //    if SetupApiLib <> 0 then FreeLibrary(SetupApiLib);
  //  end;
  //end;


begin
  //try
  //  if EjectUSB('F') then
  //    Writeln('Success')
  //  else
  //    Writeln('Failed');
  //except
  //  on E: Exception do
  //    Writeln(E.ClassName, ': ', E.Message);
  //end;
  //Readln;
end.
