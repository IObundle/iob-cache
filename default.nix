{ pkgs ? import <nixpkgs> {} }:
import ../../lib/scripts/default.nix { inherit pkgs; }
