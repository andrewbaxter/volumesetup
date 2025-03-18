{ pkgs, lib }: {
  # Creates an encrypted key file for private key volume. This encrypts a single decryption 
  # key with multiple user public keys so that any user can decrypt it to mount the volume.
  # As long as private key in `keyPath` remains the same user public keys can be freely added 
  # and removed.
  encryptKeyfile = { name, keyPath, publicKeyPaths }:
    let
      keyLines = lib.concatStringsSep " " (map (key: "--for-file ${key}") publicKeyPaths);
      encryptedPath = derivation {
        name = "${name}-volumesetup-key";
        system = builtins.currentSystem;
        builder = "${pkgs.bash}/bin/bash";
        args = [
          (pkgs.writeText "volumesetup-key-script" ''
            set -xeu
            ${pkgs.sequoia-sq}/bin/sq encrypt \
                ${keyLines} \
                --output $out \
                ${keyPath} \
                ;
          '')
        ];
      };
    in
    "${encryptedPath}";

  # Encrypt data into a file for use with `decrypt` option of private key volume decryption. The
  # data is encrypted with the volume's private key (at `keyPath`).
  encryptData = { name, keyPath, plaintext }:
    let
      decrypt = pkgs.writeText "${name}-decrypt-plaintext" plaintext;
      encryptedPath = derivation {
        name = "${name}-decrypt";
        system = builtins.currentSystem;
        builder = "${pkgs.bash}/bin/bash";
        args = [
          (pkgs.writeText "${name}-decrypt-encrypt-script" ''
            set -xeu
            ${pkgs.sequoia-sq}/bin/sq encrypt \
              --with-password-file ${keyPath} \
              --output $out \
              ${decrypt} \
              ;
          '')
        ];
      };
    in
    "${encryptedPath}";
}
