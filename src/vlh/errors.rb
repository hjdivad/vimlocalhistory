# This error indicates that a git repository could not be initialized at the
# implied path, either because the path does not exist, or the process does not
# have the necessary permissions.
class CannotInitializeRepositoryError < StandardError; end

# This error implements that an attempt has been made to use an unimplemented
# feature.
class UnimplementedFeatureError < StandardError; end

# This method requires a block to be passed in, from which a Proc will be
# constructed (i.e., yield is not called immediately, hence there is no
# LocalJumpError).
class BlockRequiredError < StandardError; end

# Indicates that an operation expected all operands to share the same options,
# but they did not.
class UnmatchedOptionsError < StandardError; end

# Indicates that vim threw an exception while trying to create a command via
# `command` or `command!` 
class CommandCreationFailedError < StandardError; end

# Indicates that an attempt was made to call a user-defined command that had not
# actually been defined.  This error is most likely a bug in VLH.
class CommandNotDefinedError < StandardError; end

# Indicates that an attempt to perform command completion was requested at an
# unexpected time, or for an unexpected command.  This error is most likely a
# bug in VLH.
class UnexpectedCompletionError < StandardError; end
