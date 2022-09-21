variable "RUST_VERSION" {
  default = "1.63"
}
variable "BIN_OUT" {
  default = "./bin"
}

target "_common" {
  args = {
    RUST_VERSION = RUST_VERSION
  }
}

group "default" {
  targets = ["binary"]
}

target "vendor" {
  inherits = ["_common"]
  target = "vendor"
  output = ["."]
}

target "binary" {
  inherits = ["_common"]
  target = "binary"
  output = [BIN_OUT]
}

target "cross" {
  inherits = ["binary"]
  platforms = [
    "linux/amd64",
    "linux/arm/v6",
    "linux/arm/v7",
    "linux/arm64"
  ]
}

target "image" {
  inherits = ["cross"]
  target = "image"
  output = ["type=image"]
}
