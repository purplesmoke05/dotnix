
### 1. Install
```fish
nix run nix-darwin -- switch --flake ~/.nix/ --impure --show-trace --verbose
```

### 2. Update
```fish
nix flake update
darwin-rebuild switch --flake . --impure --show-trace --verbose
```

### 3. GC

```fish
nix store gc
```
