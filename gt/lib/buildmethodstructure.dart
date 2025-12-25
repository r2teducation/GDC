/*
@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        child: Column(
          children: [
            // ============== HEADER ==============
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.08,
              child: const Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Register Patient",
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ),
            ),

            // ============== BODY ==============
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Form(
                  key: _formKey,
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 👇 ALL YOUR EXISTING FIELDS GO HERE
                      // Patient ID
                      // First Name
                      // Last Name
                      // Gender
                      // Age
                      // Mobile
                      // Address
                      // Referred By
                    ],
                  ),
                ),
              ),
            ),
            // ============== SOFT DEVIDER BEFORE FOOTER ==============
            const Divider(
              height: 1,
              thickness: 0.6,
              color: Color(0xFFEDEFF2),
            ),
            // ============== FOOTER ==============
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.08,
              child: Padding(
                padding: const EdgeInsets.only(right: 32),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: _loading ? null : _onSave,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Create",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  */