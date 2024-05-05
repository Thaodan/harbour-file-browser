# This file is part of File Browser.
#
# SPDX-FileCopyrightText: 2013 Michael Faro-Tusino
# SPDX-FileCopyrightText: 2013-2016 Kari Pihkala
# SPDX-FileCopyrightText: 2014 jklingen
# SPDX-FileCopyrightText: 2015 Alin Marin Elena
# SPDX-FileCopyrightText: 2018-2019 Kari Pihkala
# SPDX-FileCopyrightText: 2019-2022 Mirian Margiani
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# File Browser is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# File Browser is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <https://www.gnu.org/licenses/>.

%define __provides_exclude_from ^%{_datadir}/.*$
%bcond_with harbour_compliance

Name:       harbour-file-browser
Summary:    File Browser for Sailfish OS
# This is not a library but we try to follow semantic versioning (semver.org).
Version:    2.5.1
Release:    1
Group:      Applications/Productivity
License:    GPL-3.0-or-later
URL:        https://github.com/ichthyosaurus/harbour-file-browser
Source0:    %{name}-%{version}.tar.bz2
Requires:   sailfishsilica-qt5 >= 0.10.9
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.2
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  pkgconfig(Qt5Concurrent)
BuildRequires:  desktop-file-utils

%description
File Browser for Sailfish OS. A fully-fledged file manager for your phone.

%prep
%autosetup

%build

# HARBOUR_COMPLIANCE: set to '0' or 'o1' to enable/disable features
#      against Jolla Harbour's rules
# FEATURE_*: set to 'off' to disable optional features individually
# RELEASE_TYPE: set to a string shown on File Browser's About page
#      This should indicate whether the current build is intended for OpenRepos
#      or for Jolla's Harbour store.
# VERSION and RELEASE: automatically set to the values defined above
#
# Note: HARBOUR_COMPLIANCE and RELEASE_TYPE must be updated before building
#       for release.
#
%qmake5  \
%if %{with harbour_compliance}
    RELEASE_TYPE=Harbour \
    HARBOUR_COMPLIANCE=off
%else
    RELEASE_TYPE=OpenRepos \
%endif
    FEATURE_PDF_VIEWER=on \
    FEATURE_STORAGE_SETTINGS=on \
    FEATURE_SHARING=on \
    VERSION=%{version} \
    RELEASE=%{release}

%make_build

%install
%qmake5_install

desktop-file-install --delete-original       \
  --dir %{buildroot}%{_datadir}/applications             \
   %{buildroot}%{_datadir}/applications/*.desktop

%files
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png
