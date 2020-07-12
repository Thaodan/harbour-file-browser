%define appname harbour-file-browser-root-beta
Name: %{appname}
Summary: File Browser with root privileges
Version: 1.1
Release: 1
Group: System/Tools
License: GPLv3
Vendor: ichthyosaurus
Packager: ichthyosaurus
Source0: %{name}-%{version}.tar.xz
Provides:      application(%{appname}.desktop)
Requires:      harbour-file-browser-beta

## as long as we are in beta there is no conflict
# Conflicts:     sailfishos-filebrowserroot-patch
# Conflicts:     filebrowserroot

%description
Run File Browser with super user privileges. (For version 2.0.0+.)

A setuid helper binary is used to start the app. The source file is included
in this package:
    /usr/share/%appname/start-root-helper.c

Follow these steps to rebuild the start helper:
    $ gcc "/usr/share/%appname/start-root-helper.c" -o "/usr/share/%appname/start-root"
    $ chmod 4755 "/usr/share/%appname/start-root"

Sources and documentation can be found online:
    https://github.com/ichthyosaurus/harbour-file-browser/

%prep
%setup -q -n %{name}-%{version}

%build
gcc start-root-helper.c -o start-root
chmod 4755 start-root

%install
rm -rf %{buildroot}

mkdir -p %{buildroot}/usr/share/applications
mkdir -p %{buildroot}/usr/share/%appname

for d in "86x86" "108x108" "128x128" "172x172"; do
    mkdir -p "%{buildroot}/usr/share/icons/hicolor/$d/apps"
    cp "icons/$d/"*.png "%{buildroot}/usr/share/icons/hicolor/$d/apps"
done

cp %appname.desktop %{buildroot}/usr/share/applications/
cp start-root start-root-helper.c %{buildroot}/usr/share/%appname/

%changelog

* Sun May 10 2020 ichthyosaurus <33604595+ichthyosaurus@users.noreply.github.com> 1.1-1
- Fixed starting from the terminal

* Sat May 02 2020 ichthyosaurus <33604595+ichthyosaurus@users.noreply.github.com> 1.0-1
- Fixed building
- Added and improved documentation
- Included in harbour-file-browser's main repository

* Mon Dec 30 2019 ichthyosaurus <33604595+ichthyosaurus@users.noreply.github.com> 0.4-1
- Made compatible with released version 2.0.0+ (beta) of File Browser
- Renamed and rebuilt package
- Added re-build instructions to RPM description

* Tue Jun 04 2019 ichthyosaurus <33604595+ichthyosaurus@users.noreply.github.com> 0.3-1
- Forked version 0.2-5 of filebrowserroot by Schturman
- Refactored using correct icons and fixed launcher entry
- Renamed to be more similar to File Browser

* Wed Feb 06 2019 Builder <schturman@hotmail.com> 0.2-5
- Changes in SPEC file. Obsoletes changed to Conflicts.

%files
%attr(0644, root, root) "/usr/share/applications/%appname.desktop"
%attr(0644, root, root) "/usr/share/icons/hicolor/86x86/apps/%appname.png"
%attr(0644, root, root) "/usr/share/icons/hicolor/108x108/apps/%appname.png"
%attr(0644, root, root) "/usr/share/icons/hicolor/128x128/apps/%appname.png"
%attr(0644, root, root) "/usr/share/icons/hicolor/172x172/apps/%appname.png"
%attr(4755, root, root) "/usr/share/%appname/start-root"
%attr(0644, root, root) "/usr/share/%appname/start-root-helper.c"
