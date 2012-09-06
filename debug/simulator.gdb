set shlib-path-substitutions / /Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator5.0.sdk/
define penv
	set $env = (char **)environ
	set $i = 0
	while $env[$i] != 0
		p $env[$i]
		set $i = $i+1
	end
end

