; --- إعدادات المشروع ---
#define MyAppName "Business Pro"
#define MyAppVersion "1.0"
#define MyAppPublisher "Business Pro Solutions"
#define MyAppExeName "business_pro.exe"

[Setup]
; --- المعرف الفريد (متغيروش عشان التحديثات المستقبلية) ---
AppId={{A59074B5-5F84-4E53-9366-2673295D345C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}

; --- مكان التسطيب (Program Files) ---
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}

; --- إعدادات الخرج (مكان ملف الـ Setup النهائي) ---
OutputDir=.\Installers
OutputBaseFilename=BusinessPro_Setup_v1
; ضغط عالي عشان الملف يكون صغير
Compression=lzma
SolidCompression=yes

; --- الأيقونات (لو معندكش ملف .ico امسح السطر اللي جاي ده) ---
; SetupIconFile=assets\logo.ico

; --- صلاحيات التسطيب (Admin عشان يكتب في Program Files) ---
PrivilegesRequired=admin

; --- التوافق مع 64 بت ---
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
; لو عايز عربي ممكن تنزل ملف الترجمة وتضيفه هنا

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; --- تجميع الملفات (أهم جزء) ---
; المسار ده بيجيب كل حاجة من فولدر الـ Release اللي طلع من Flutter
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; لاحظ: النجمة * معناها هات كل الملفات واللابراريز اللي جنب الـ exe

[Icons]
; أيقونة سطح المكتب وقائمة Start
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; تشغيل البرنامج بعد التسطيب
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent