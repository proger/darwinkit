HOOK=		notificationhook
PROVIDER=	notification.provider

$(HOOK).dylib: $(HOOK).m $(PROVIDER).h
	clang -framework Foundation -shared -flat_namespace $< -o $@

$(PROVIDER).h: $(PROVIDER).d
	dtrace -h -s $<

clean:
	rm -f $(HOOK).dylib $(PROVIDER).h

apply:
	@test "$(PID)" -ge 1 2>/dev/null || (echo error: specify PID=; false)
	cat hook.lldb | python ../../lldb-run.py $(PID)
	sudo dtrace -m $(HOOK).dylib -l

.PHONY: clean
