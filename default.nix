# SPDX-FileCopyrightText: 2024 IObundle
#
# SPDX-License-Identifier: MIT

{ pkgs ? import <nixpkgs> {} }:

let
  py2hwsw_commit = "76348e0e463d9573f34370f2295dd5192f82639c"; # Replace with the desired commit.
  py2hwsw_sha256 = "REIDi82mYwqeuh0zEJ4bjmGhiti89+7i9jHyBf1vc7I="; # Replace with the actual SHA256 hash.
  # Get local py2hwsw root from `PY2HWSW_ROOT` env variable
  py2hwswRoot = builtins.getEnv "PY2HWSW_ROOT";

  # For debug
  disable_py2_build = 0;

  py2hwsw = 
    if disable_py2_build == 0 then
      pkgs.python3.pkgs.buildPythonPackage rec {
        pname = "py2hwsw";
        version = py2hwsw_commit;
        src =
          if py2hwswRoot != "" then
            pkgs.lib.cleanSource py2hwswRoot
          else
            (pkgs.fetchFromGitHub {
              owner = "IObundle";
              repo = "py2hwsw";
              rev = py2hwsw_commit;
              sha256 = py2hwsw_sha256;
              fetchSubmodules = true;
            }).overrideAttrs (_: {
              GIT_CONFIG_COUNT = 1;
              GIT_CONFIG_KEY_0 = "url.https://github.com/.insteadOf";
              GIT_CONFIG_VALUE_0 = "git@github.com:";
            });
        # Add any necessary dependencies here.
        #propagatedBuildInputs = [ pkgs.python38Packages.someDependency ];
      }
    else
      null;


in

if disable_py2_build == 0 then
  import "${py2hwsw}/lib/python${builtins.substring 0 4 pkgs.python3.version}/site-packages/py2hwsw/lib/default.nix" { inherit pkgs; py2hwsw_pkg = py2hwsw; }
else
  import "${py2hwswRoot}/py2hwsw/lib/default.nix" { inherit pkgs; py2hwsw_pkg = py2hwsw; }
