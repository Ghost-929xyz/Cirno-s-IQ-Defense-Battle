param([Parameter(Mandatory=$true)][string]$Template, [Parameter(Mandatory=$true)][string]$Icon, [Parameter(Mandatory=$true)][string]$Destination)
$ErrorActionPreference = 'Stop'
# Patch a private copy of the export template BEFORE Godot appends its PCK.
Copy-Item -LiteralPath $Template -Destination $Destination -Force
if (-not ('DemoIconResources' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class DemoIconResources {
  delegate bool Names(IntPtr module, IntPtr type, IntPtr name, IntPtr data);
  delegate bool Languages(IntPtr module, IntPtr type, IntPtr name, ushort lang, IntPtr data);
  [DllImport("kernel32", CharSet=CharSet.Unicode)] static extern IntPtr LoadLibraryEx(string path,IntPtr file,uint flags);
  [DllImport("kernel32")] static extern bool FreeLibrary(IntPtr module);
  [DllImport("kernel32", CharSet=CharSet.Unicode)] static extern bool EnumResourceNames(IntPtr module,IntPtr type,Names callback,IntPtr data);
  [DllImport("kernel32", CharSet=CharSet.Unicode)] static extern bool EnumResourceLanguages(IntPtr module,IntPtr type,IntPtr name,Languages callback,IntPtr data);
  [DllImport("kernel32", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr BeginUpdateResource(string path,bool delete);
  [DllImport("kernel32", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool UpdateResource(IntPtr update,IntPtr type,IntPtr name,ushort lang,byte[] data,uint length);
  [DllImport("kernel32", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool EndUpdateResource(IntPtr update,bool discard);
  public static void Apply(string path,string icon) {
    var names=new List<Tuple<string,int,ushort>>();
    var module=LoadLibraryEx(path,IntPtr.Zero,2);
    if(module==IntPtr.Zero) throw new Exception("Cannot inspect export template");
    EnumResourceNames(module,(IntPtr)14,(m,t,n,d)=> {
      string text=n.ToInt64()>65535?Marshal.PtrToStringUni(n):null;
      int id=text==null?n.ToInt32():0;
      EnumResourceLanguages(m,t,n,(mm,tt,nn,l,dd)=> {names.Add(Tuple.Create(text,id,l));return true;},IntPtr.Zero);
      return true;
    },IntPtr.Zero);
    FreeLibrary(module);
    if(names.Count==0) names.Add(Tuple.Create((string)null,1,(ushort)0));
    var bytes=File.ReadAllBytes(icon);
    var reader=new BinaryReader(new MemoryStream(bytes));
    reader.ReadUInt16();reader.ReadUInt16();int count=reader.ReadUInt16();
    var group=new MemoryStream();var writer=new BinaryWriter(group);
    writer.Write((ushort)0);writer.Write((ushort)1);writer.Write((ushort)count);
    var images=new List<byte[]>();
    for(int i=0;i<count;i++) {
      var entry=reader.ReadBytes(12); uint offset=reader.ReadUInt32();
      int size=BitConverter.ToInt32(entry,8);var frame=new byte[size];
      Array.Copy(bytes,(int)offset,frame,0,size); images.Add(frame);
      writer.Write(entry);writer.Write((ushort)(i+1));
    }
    var handle=BeginUpdateResource(path,false);
    if(handle==IntPtr.Zero) throw new Exception("Cannot update template icon");
    bool committed=false;
    try {
      foreach(var name in names) {
        for(int i=0;i<count;i++) if(!UpdateResource(handle,(IntPtr)3,(IntPtr)(i+1),name.Item3,images[i],(uint)images[i].Length)) throw new Exception("Icon resource write failed");
        var pointer=name.Item1==null?(IntPtr)name.Item2:Marshal.StringToHGlobalUni(name.Item1);
        try {var data=group.ToArray();if(!UpdateResource(handle,(IntPtr)14,pointer,name.Item3,data,(uint)data.Length)) throw new Exception("Icon group write failed");}
        finally {if(name.Item1!=null) Marshal.FreeHGlobal(pointer);}
      }
      if(!EndUpdateResource(handle,false)) throw new Exception("Icon commit failed");
      committed=true;
    } finally {if(!committed) EndUpdateResource(handle,true);}
  }
}
'@
}
[DemoIconResources]::Apply((Resolve-Path -LiteralPath $Destination).Path,(Resolve-Path -LiteralPath $Icon).Path)
