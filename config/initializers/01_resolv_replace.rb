# Fix for IPv6 connection timeouts (hanging) when connecting to Telegram API.
# This replaces the standard libc resolver with Ruby's Resolv class.
require 'resolv-replace'
