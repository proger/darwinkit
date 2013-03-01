
/*
 * XXX: this works only with compile-time CFStrings
 * 	hitting other types of CFStrings will produce user faults
 */
#define cfstring(p) copyinstr(*(user_addr_t *)copyin(p + 2*sizeof(user_addr_t), sizeof(user_addr_t)))
