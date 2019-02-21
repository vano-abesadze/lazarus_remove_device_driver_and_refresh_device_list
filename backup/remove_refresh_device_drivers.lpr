program remove_refresh_device_drivers;

uses Classes, SysUtils,device_helper;

var
  param,a1,a2,a3:string;
begin


    param:=ParamStr(1);
  WriteLn('Type /help for see help, run this program as an administrator privilege');
//  WriteLn('პარემეტრი /help დახმარების გამოძახება, გაუშვით ეს პროგრამა ადმინისტრატორის უფლებით');

  if param='/help' then
  begin
     WriteLn('command line parameters');
     WriteLn('Example command line:AR9485^1');
     WriteLn('"AR9485" it is device removal name contains name, AR9485 is "Qualcomm Atheros AR9485WB-EG Wireless Network Adapter"');
     WriteLn('1 it is device remove');
     //WriteLn('0 it is rescan parameters if 0 no rescan if 1 rescan device list');
     WriteLn('Press ENTER key to close');
//     WriteLn('----------------------------------------------------------------------------');
//
//     WriteLn('ბრძანების პარამეტრები');
//     WriteLn('მაგალითი:AR9485^1^);
//     WriteLn('AR9485 ამ სახელით მოძებნის მოწყობილობას მაგალითად ეს AR9485 მოძებნის "Qualcomm Atheros AR9485WB-EG Wireless Network Adapter" მოწყობილობას');
//     WriteLn('1 მოწყობილობის ამოშლა');
//     WriteLn('0 ამოშლის შემდეგ ხელახალი სკანირება თუ 1 მაშინ მოხდება ხელახალი სკანირება თუ 0 არა');
//     WriteLn('Press ENTER key to close დააჭირეთ ენტერ კლავიშს დახურვისათვის');
     Readln;
  end
  else
  begin
    //  showmessage(param);


      a3:=param;

      WriteLn(a3);
      WriteLn('');

      a3:=StringReplace(a3,'"','',[rfReplaceAll]);

      a1:=copy(a3,0,pos('^',a3)-1);
      WriteLn(a1);
      WriteLn('');
    //  showmessage(param);
      delete(a3,1,pos('^',a3));
    //  showmessage(param);
      //a2:=copy(param,0,pos('^',param)-1);
      WriteLn(a3);
    //  showmessage(param);
    //  delete(param,1,pos('^',param));
    //  showmessage(param);
    //  a3:=param;






    //  readln;

//         if a3='1' then refresh ;
      remove_device_(a1);
        sleep(10000);
      if a3='1' then refresh ;

  end;





end.

