#!/usr/bin/env python3

from collections import OrderedDict
import sys, subprocess, re, os

PKG_DESC = {
"cpp": OrderedDict([
    ("Package", "%(name)s-%(DEB_TARGET_GNU_TYPE)s"),
    ("Architecture", "all"),
    ("Depends", "%(name)s-%(major)s-%(DEB_TARGET_GNU_TYPE)s (>= %(Version)s), ${misc:Depends}"),
    ("Description", """GNU C cross-preprocessor (cpp)
 This is the GNU C preprocessor cpp built for cross-building %(DEB_TARGET_ARCH)s
 binaries/packages. This is actually a metapackage that will bring in the
 correct versioned cpp cross package and symlink to it.""")
    ]),

"gcc": ([
    ("Package", "%(name)s-%(DEB_TARGET_GNU_TYPE)s"),
    ("Architecture", "all"),
    ("Provides", "c-compiler:%(DEB_TARGET_ARCH)s"),
    ("Depends", "%(name)s-%(major)s-%(DEB_TARGET_GNU_TYPE)s (>= %(Version)s), ${misc:Depends}"),
    ("Description", """GNU C cross-compiler
 This is the GNU C compiler built for cross-building %(DEB_TARGET_ARCH)s
 binaries/packages. This is actually a metapackage that will bring in the
 correct versioned gcc cross package and symlink to it.""")
]),

"g++": ([
    ("Package", "%(name)s-%(DEB_TARGET_GNU_TYPE)s"),
    ("Architecture", "all"),
    ("Provides", "g++:%(DEB_TARGET_ARCH)s (= 4:%(Version)s), c++:%(DEB_TARGET_ARCH)s (= 4:%(Version)s), c++-compiler:%(DEB_TARGET_ARCH)s, c++abi2-dev:%(DEB_TARGET_ARCH)s, build-essential:%(DEB_TARGET_ARCH)s (= 12.1)"),
    ("Depends", "%(name)s-%(major)s-%(DEB_TARGET_GNU_TYPE)s (>= %(Version)s), ${misc:Depends}"),
    ("Description", """GNU C++ cross-compiler
 This is the GNU C++ compiler built for cross-building %(DEB_TARGET_ARCH)s
 binaries/packages. This is actually a metapackage that will bring in the
 correct versioned gcc cross package and symlink to it.""")
    ]),

"gfortran": ([
    ("Package", "%(name)s-%(DEB_TARGET_GNU_TYPE)s"),
    ("Architecture", "all"),
    ("Provides", "fortran-compiler:%(DEB_TARGET_ARCH)s, fortran95-compiler:%(DEB_TARGET_ARCH)s, fortran77-compiler:%(DEB_TARGET_ARCH)s, gfortran-mod-14:%(DEB_TARGET_ARCH)s"),
    ("Depends", "%(name)s-%(major)s-%(DEB_TARGET_GNU_TYPE)s (>= %(Version)s), ${misc:Depends}"),
    ("Description", """GNU Fortran 95 cross-compiler
 This is the GNU Fortran 95 compiler built for cross-building %(DEB_TARGET_ARCH)s
 binaries/packages. This is actually a metapackage that will bring in
 the correct versioned gcc cross package and symlink to it.""")
    ]),

"gobjc": ([
    ("Package", "%(name)s-%(DEB_TARGET_GNU_TYPE)s"),
    ("Architecture", "all"),
    ("Provides", "objc-compiler:%(DEB_TARGET_ARCH)s"),
    ("Depends", "%(name)s-%(major)s-%(DEB_TARGET_GNU_TYPE)s (>= %(Version)s), ${misc:Depends}"),
    ("Description", """GNU objective C cross-compiler
 This is the GNU objective C compiler built for cross-building %(DEB_TARGET_ARCH)s
 binaries/packages. This is actually a metapackage that will bring in the
 correct versioned gcc cross package and symlink to it.""")
    ]),

"gccgo": ([ 
    ("Package", "%(name)s-%(DEB_TARGET_GNU_TYPE)s"),
    ("Architecture", "all"),
    ("Provides", "go-compiler:%(DEB_TARGET_ARCH)s"),
    ("Depends", "%(name)s-%(major)s-%(DEB_TARGET_GNU_TYPE)s (>= %(Version)s), ${misc:Depends}"),
    ("Description", """GNU go cross-compiler
 This is the GNU go compiler built for cross-building %(DEB_TARGET_ARCH)s
 binaries/packages. This is actually a metapackage that will bring in the
 correct versioned gcc cross package and symlink to it.""")
    ])
}


class Field:
    def __init__(self, pkg, k, v):
        self.pkg = pkg
        self.name = k
        self.value = v

    def __repr__(self):
        return "%s: %s" % (self.name, self.pkg.expand(self.value))


reSUBST = re.compile(r".*%\(\w+\)s.*")

class Package:
    vals = {
    }
    def __init__(self):
        self._fields = {}
        self._vals = dict(self.vals)

    def __repr__(self):
        return "\n".join(ii.__repr__() for ii in self.fields)

    @property
    def fields(self):
        return [Field(self, k, v) for k, v in self._fields.items()]

    def expand(self, val):
        exp = val % self._vals
        if reSUBST.match(exp):
            return self.expand(exp)
        else:
            return exp


class DebianPackage(Package):
    vals = {
    }
    def __init__(self, name, desc, target=None, ver="5.2"):
        super(DebianPackage, self).__init__()
        _vals = self._vals
        _vals["major"], _vals["minor"] = ver.split(".", 1)
        _vals["name"] = name
        _vals["Version"] = "%(major)s.%(minor)s"

        # Visible fields
        self._fields = _fields = OrderedDict(desc)
        assert("Description" in self._fields)
        assert("Architecture" in self._fields)
        assert("Description" in self._fields)

        _fields.move_to_end("Description")

        # All fields (including hidden)
        _vals.update(_fields)
        _vals.update(self.get_deb_archs(target=target))

    def get_deb_archs(self, host=None, target=None):
        args = ["dpkg-architecture"]
        if host:
            args.append("-a%s" % host)
        if target:
            args.append("-A%s" % target)
        c = subprocess.run(args, stdout=subprocess.PIPE, check=True)
        lines = (l.split("=") for l in c.stdout.decode("ascii").split("\n") if l)
        return {k: v.replace("_", "-") for k, v in lines}
        
def get_env_default(k):
    def_envs = {
        "TARGET_LIST":      "amd64 i386",
    }
    if os.environ.get(k):
        v = os.environ[k]
    else:
        v = def_envs.get(k, "")
        sys.stderr.write("%s variable not set, using default: %s\n" % (k, v))
    
    return v 

def main():
    sys.stdout.write(open(os.path.join(os.path.dirname(sys.argv[0]), "control.head.in"), "r").read())
    print("\n")
    targets = get_env_default("TARGET_LIST").split()
    packages = get_env_default("PACKAGE_LIST").split()
    ver = get_env_default("VER")
    
    for target in targets:
        for pkg in packages:
            print("%s\n" % DebianPackage(pkg, PKG_DESC[pkg], target, ver))


if __name__ == "__main__":
    main()

