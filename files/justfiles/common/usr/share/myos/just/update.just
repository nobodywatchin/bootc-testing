# default recipe (optional)
default:
  @echo "Run \`just update-system\` to upgrade the OS"

# Update the system using bootc
update-system:
  sudo bootc upgrade
