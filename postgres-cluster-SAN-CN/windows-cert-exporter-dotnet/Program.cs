using System.Runtime.InteropServices;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.IO;

namespace ConsoleApp1
{
    /// <summary>
    /// Certificate Export Tool - Exports certificates from Windows Certificate Store
    /// 
    /// This program searches the Windows Certificate Store (CurrentUser\Personal and CurrentUser\Root)
    /// for certificates matching a specified search term in either the subject name or 
    /// Subject Alternative Names (SAN), then exports them to PEM format files.
    /// 
    /// COMMAND LINE USAGE:
    /// ==================
    /// 
    /// Basic Usage:
    /// ------------
    /// dotnet run                                          // Search for "localhost" (default)
    /// dotnet run -- -s "127.0.0.1"                      // Search for specific term
    /// dotnet run -- --search "myserver.com"             // Same as above
    /// 
    /// Output Directory:
    /// ----------------
    /// dotnet run -- -o "C:\ssl-certs"                   // Custom output directory
    /// dotnet run -- --output "D:\certificates"          // Same as above
    /// 
    /// Search Options:
    /// --------------
    /// dotnet run -- --subject-only                      // Search only in certificate subject
    /// dotnet run -- --san-only                          // Search only in Subject Alternative Names
    /// dotnet run -- --search "localhost" --san-only     // Find certs with "localhost" in SAN
    /// 
    /// Help:
    /// -----
    /// dotnet run -- --help                              // Show usage information
    /// dotnet run -- -h                                  // Same as above
    /// 
    /// USING COMPILED EXECUTABLE:
    /// ==========================
    /// 
    /// After building (dotnet build), you can run the executable directly:
    /// 
    /// cd "C:\Users\Ozkan.Pakdil\RiderProjects\ConsoleApp1\ConsoleApp1\bin\Debug\net9.0"
    /// 
    /// .\ConsoleApp1.exe                                  // Default search
    /// .\ConsoleApp1.exe -s "localhost"                  // Search for localhost
    /// .\ConsoleApp1.exe --search "127.0.0.1" --san-only // Search IP in SAN only
    /// .\ConsoleApp1.exe -o "C:\temp" -s "myserver"      // Custom output and search
    /// 
    /// REAL-WORLD EXAMPLES:
    /// ===================
    /// 
    /// PostgreSQL Certificates:
    /// ------------------------
    /// // Find PostgreSQL server certificates that contain localhost
    /// dotnet run -- --search "localhost" --san-only
    /// 
    /// // Export certificates for a specific server
    /// dotnet run -- -s "postgresql-server.local" -o "C:\postgresql\ssl"
    /// 
    /// Development Certificates:
    /// ------------------------
    /// // Find all localhost development certificates
    /// dotnet run -- -s "localhost"
    /// 
    /// // Find certificates by IP address
    /// dotnet run -- --search "127.0.0.1" --san-only
    /// 
    /// Production Server Certificates:
    /// ------------------------------
    /// // Export production server certificates
    /// dotnet run -- -s "api.mycompany.com" -o "C:\production-certs"
    /// 
    /// SUBJECT ALTERNATIVE NAMES (SAN) SUPPORT:
    /// ========================================
    /// 
    /// This tool can find certificates with multiple server names like:
    /// - DNS.1 = localhost
    /// - DNS.2 = myserver.local
    /// - DNS.3 = 127.0.0.1
    /// - IP.1 = 127.0.0.1
    /// - IP.2 = ::1
    /// 
    /// The --san-only option is perfect for finding certificates by any of these alternative names.
    /// 
    /// OUTPUT FILES:
    /// ============
    /// 
    /// For each certificate found, three files are created:
    /// - {CommonName}_{timestamp}_{index}.crt  // Certificate in PEM format
    /// - {CommonName}_{timestamp}_{index}.key  // Private key in PEM format (if available)
    /// - {CommonName}_{timestamp}_{index}.pfx  // Certificate + private key in PFX format
    /// 
    /// PERMISSIONS:
    /// ===========
    /// 
    /// Run as Administrator if you encounter permission issues accessing certificate stores.
    /// The tool accesses CurrentUser certificate stores, which typically don't require admin rights.
    /// 
    /// TROUBLESHOOTING:
    /// ===============
    /// 
    /// If private key export fails:
    /// - The tool will export PFX format as fallback
    /// - Use OpenSSL to convert: openssl pkcs12 -in cert.pfx -out cert.key -nodes -nocerts
    /// 
    /// If no certificates found:
    /// - Try searching without --subject-only or --san-only restrictions
    /// - Check if certificates are in LocalMachine store instead of CurrentUser
    /// - Verify the search term matches exactly (search is case-insensitive)
    /// </summary>
    class Program
    {
        private const string DefaultOutputDir = @"C:\tmp\certs\";
        // Make these parametrizable
        private static string _searchTerm = "localhost"; // Default search term
        private static bool _searchInSan = true; // Search in SAN by default
        private static bool _searchInSubject = true; // Search in subject by default

        [DllImport("crypt32.dll", SetLastError = true)]
        private static extern bool CryptAcquireCertificatePrivateKey(
            IntPtr pCert,
            uint dwFlags,
            IntPtr pvReserved,
            out IntPtr phCryptProvOrNCryptKey,
            out uint pdwKeySpec,
            out bool pfCallerFreeProvOrNCryptKey);

        static void Main(string[] args)
        {
            try
            {
                string outputDir = DefaultOutputDir;
                
                // Parse command line arguments
                if (args.Length > 0)
                {
                    for (int i = 0; i < args.Length; i++)
                    {
                        switch (args[i].ToLower())
                        {
                            case "-o":
                            case "--output":
                                if (i + 1 < args.Length)
                                    outputDir = args[++i];
                                break;
                            case "-s":
                            case "--search":
                                if (i + 1 < args.Length)
                                    _searchTerm = args[++i];
                                break;
                            case "--subject-only":
                                _searchInSan = false;
                                _searchInSubject = true;
                                break;
                            case "--san-only":
                                _searchInSan = true;
                                _searchInSubject = false;
                                break;
                            case "-h":
                            case "--help":
                                ShowUsage();
                                return;
                        }
                    }
                }

                // Ensure output directory exists
                Directory.CreateDirectory(outputDir);

                var timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
                Console.WriteLine($"Searching for certificates containing: '{_searchTerm}'");
                Console.WriteLine($"Search in Subject: {_searchInSubject}");
                Console.WriteLine($"Search in SAN: {_searchInSan}");
                Console.WriteLine($"Exporting certificates to: {outputDir}");
                Console.WriteLine($"Timestamp: {timestamp}");

                // Search and export certificates from Personal store
                ExportCertificatesFromStore(StoreName.My, StoreLocation.CurrentUser, outputDir, timestamp, "Personal");
                
                // Also search in Root store for completeness
                ExportCertificatesFromStore(StoreName.Root, StoreLocation.CurrentUser, outputDir, timestamp, "Root");

                Console.WriteLine("\nCertificate export completed!");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
            }
        }

        private static void ShowUsage()
        {
            Console.WriteLine("Certificate Export Tool");
            Console.WriteLine("Usage: ConsoleApp1.exe [options]");
            Console.WriteLine();
            Console.WriteLine("Options:");
            Console.WriteLine("  -o, --output <dir>    Output directory (default: C:\\tmp\\certs\\)");
            Console.WriteLine("  -s, --search <term>   Search term (default: localhost)");
            Console.WriteLine("  --subject-only        Search only in certificate subject");
            Console.WriteLine("  --san-only           Search only in Subject Alternative Names");
            Console.WriteLine("  -h, --help           Show this help message");
            Console.WriteLine();
            Console.WriteLine("Examples:");
            Console.WriteLine("  ConsoleApp1.exe -s \"localhost\" -o \"C:\\temp\\\"");
            Console.WriteLine("  ConsoleApp1.exe --search \"127.0.0.1\" --san-only");
        }

        private static void ExportCertificatesFromStore(StoreName storeName, StoreLocation storeLocation, string outputDir, string timestamp, string storeDisplayName)
        {
            Console.WriteLine($"\n--- Searching in {storeDisplayName} Store ---");
            
            using var store = new X509Store(storeName, storeLocation);
            store.Open(OpenFlags.ReadOnly);

            var matchingCertificates = FindCertificatesBySearchTerm(store.Certificates, _searchTerm);
            
            if (matchingCertificates.Count == 0)
            {
                Console.WriteLine($"No certificates found matching '{_searchTerm}' in {storeDisplayName} store.");
                return;
            }

            Console.WriteLine($"Found {matchingCertificates.Count} matching certificate(s) in {storeDisplayName} store:");

            for (int i = 0; i < matchingCertificates.Count; i++)
            {
                var cert = matchingCertificates[i];
                var certIndex = i + 1;
                
                Console.WriteLine($"\n  Certificate {certIndex}:");
                Console.WriteLine($"    Subject: {cert.Subject}");
                Console.WriteLine($"    Issuer: {cert.Issuer}");
                Console.WriteLine($"    Valid From: {cert.NotBefore}");
                Console.WriteLine($"    Valid Until: {cert.NotAfter}");
                Console.WriteLine($"    Thumbprint: {cert.Thumbprint}");
                Console.WriteLine($"    Has Private Key: {cert.HasPrivateKey}");
                
                // Display SAN information
                DisplaySubjectAlternativeNames(cert);
                
                // Generate file names
                var sanitizedSubject = SanitizeFileName(GetCommonName(cert.Subject));
                var certPath = Path.Combine(outputDir, $"{sanitizedSubject}_{timestamp}_{certIndex}.crt");
                var keyPath = Path.Combine(outputDir, $"{sanitizedSubject}_{timestamp}_{certIndex}.key");
                var pfxPath = Path.Combine(outputDir, $"{sanitizedSubject}_{timestamp}_{certIndex}.pfx");

                // Export public certificate
                var certPem = ExportCertificateToPem(cert);
                File.WriteAllText(certPath, certPem);
                Console.WriteLine($"    ✓ Certificate exported to: {certPath}");

                // Export private key if available
                if (cert.HasPrivateKey)
                {
                    try
                    {
                        var privateKeyPem = ExportPrivateKeyToPem(cert);
                        if (!string.IsNullOrEmpty(privateKeyPem) && !privateKeyPem.StartsWith("#"))
                        {
                            File.WriteAllText(keyPath, privateKeyPem);
                            Console.WriteLine($"    ✓ Private key exported to: {keyPath}");
                        }
                        else if (!string.IsNullOrEmpty(privateKeyPem))
                        {
                            Console.WriteLine($"    ℹ {privateKeyPem}");
                        }

                        // Export as PFX (with empty password)
                        var pfxBytes = cert.Export(X509ContentType.Pfx, "");
                        File.WriteAllBytes(pfxPath, pfxBytes);
                        Console.WriteLine($"    ✓ PFX exported to: {pfxPath}");
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"    ✗ Error exporting private key: {ex.Message}");
                    }
                }
                else
                {
                    Console.WriteLine("    ⚠ No private key available.");
                }
            }

            store.Close();
        }

        private static X509Certificate2Collection FindCertificatesBySearchTerm(X509Certificate2Collection certificates, string searchTerm)
        {
            var matchingCertificates = new X509Certificate2Collection();
            
            foreach (X509Certificate2 cert in certificates)
            {
                bool matches = false;
                
                // Search in subject name if enabled
                if (_searchInSubject && cert.Subject.Contains(searchTerm, StringComparison.OrdinalIgnoreCase))
                {
                    matches = true;
                }
                
                // Search in SAN if enabled and not already matched
                if (!matches && _searchInSan)
                {
                    matches = CertificateContainsInSan(cert, searchTerm);
                }
                
                if (matches)
                {
                    matchingCertificates.Add(cert);
                }
            }
            
            return matchingCertificates;
        }

        private static bool CertificateContainsInSan(X509Certificate2 cert, string searchTerm)
        {
            try
            {
                // Look for Subject Alternative Name extension
                foreach (X509Extension extension in cert.Extensions)
                {
                    if (extension.Oid?.Value == "2.5.29.17") // SAN OID
                    {
                        var sanExtension = new X509SubjectAlternativeNameExtension(extension.RawData, false);
                        var sanEntries = GetSubjectAlternativeNames(sanExtension);
                        
                        foreach (var entry in sanEntries)
                        {
                            if (entry.Contains(searchTerm, StringComparison.OrdinalIgnoreCase))
                            {
                                return true;
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"    Warning: Error reading SAN extension: {ex.Message}");
            }
            
            return false;
        }

        private static void DisplaySubjectAlternativeNames(X509Certificate2 cert)
        {
            try
            {
                foreach (X509Extension extension in cert.Extensions)
                {
                    if (extension.Oid?.Value == "2.5.29.17") // SAN OID
                    {
                        var sanExtension = new X509SubjectAlternativeNameExtension(extension.RawData, false);
                        var sanEntries = GetSubjectAlternativeNames(sanExtension);
                        
                        if (sanEntries.Any())
                        {
                            Console.WriteLine($"    Subject Alternative Names:");
                            foreach (var entry in sanEntries)
                            {
                                Console.WriteLine($"      - {entry}");
                            }
                        }
                        break;
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"    Warning: Could not read SAN extension: {ex.Message}");
            }
        }

        private static List<string> GetSubjectAlternativeNames(X509SubjectAlternativeNameExtension sanExtension)
        {
            var sanEntries = new List<string>();
            
            try
            {
                // Parse the raw data to extract SAN entries
                var rawData = sanExtension.RawData;
                
                // Simple parsing of ASN.1 DER encoded SAN extension
                // This is a basic implementation - for production use, consider using a proper ASN.1 library
                for (int i = 0; i < rawData.Length; i++)
                {
                    if (rawData[i] == 0x82) // DNS name tag
                    {
                        i++; // Move to length byte
                        if (i < rawData.Length)
                        {
                            int length = rawData[i];
                            i++; // Move to data
                            if (i + length <= rawData.Length)
                            {
                                string dnsName = Encoding.UTF8.GetString(rawData, i, length);
                                sanEntries.Add($"DNS: {dnsName}");
                                i += length - 1; // -1 because loop will increment
                            }
                        }
                    }
                    else if (rawData[i] == 0x87) // IP address tag
                    {
                        i++; // Move to length byte
                        if (i < rawData.Length)
                        {
                            int length = rawData[i];
                            i++; // Move to data
                            if (i + length <= rawData.Length && length == 4) // IPv4
                            {
                                string ipAddress = $"{rawData[i]}.{rawData[i + 1]}.{rawData[i + 2]}.{rawData[i + 3]}";
                                sanEntries.Add($"IP: {ipAddress}");
                                i += length - 1; // -1 because loop will increment
                            }
                            else if (i + length <= rawData.Length && length == 16) // IPv6
                            {
                                var ipBytes = new byte[16];
                                Array.Copy(rawData, i, ipBytes, 0, 16);
                                string ipAddress = new System.Net.IPAddress(ipBytes).ToString();
                                sanEntries.Add($"IP: {ipAddress}");
                                i += length - 1; // -1 because loop will increment
                            }
                        }
                    }
                }
            }
            catch (Exception)
            {
                // Fallback: try to use the formatted string from the extension
                try
                {
                    string formattedString = sanExtension.Format(false);
                    var lines = formattedString.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
                    sanEntries.AddRange(lines.Where(line => !string.IsNullOrWhiteSpace(line)));
                }
                catch
                {
                    // If all else fails, just indicate that SAN is present
                    sanEntries.Add("SAN present but could not parse");
                }
            }
            
            return sanEntries;
        }

        private static string GetCommonName(string subject)
        {
            // Extract CN from subject string
            var parts = subject.Split(',');
            foreach (var part in parts)
            {
                var trimmedPart = part.Trim();
                if (trimmedPart.StartsWith("CN=", StringComparison.OrdinalIgnoreCase))
                {
                    return trimmedPart.Substring(3);
                }
            }
            return "certificate";
        }

        private static string SanitizeFileName(string fileName)
        {
            var invalidChars = Path.GetInvalidFileNameChars();
            foreach (char c in invalidChars)
            {
                fileName = fileName.Replace(c, '_');
            }
            return fileName;
        }

        private static string ExportCertificateToPem(X509Certificate2 cert)
        {
            var certBytes = cert.Export(X509ContentType.Cert);
            var base64 = Convert.ToBase64String(certBytes, Base64FormattingOptions.InsertLineBreaks);
            
            var builder = new StringBuilder();
            builder.AppendLine("-----BEGIN CERTIFICATE-----");
            builder.AppendLine(base64);
            builder.AppendLine("-----END CERTIFICATE-----");
            
            return builder.ToString();
        }

        private static bool HasPrivateKey(X509Certificate2 cert)
        {
            try
            {
                return cert.HasPrivateKey;
            }
            catch
            {
                return false;
            }
        }

        private static string ExportPrivateKeyToPem(X509Certificate2 cert)
        {
            try
            {
                // Try modern ECDsa first
                var ecdsaKey = cert.GetECDsaPrivateKey();
                if (ecdsaKey != null)
                {
                    return ExportECDsaPrivateKeyToPem(ecdsaKey);
                }

                // Try RSA with CNG provider
                var rsaKey = cert.GetRSAPrivateKey();
                if (rsaKey != null)
                {
                    try
                    {
                        // Try PKCS#8 format first (more compatible)
                        var pkcs8Bytes = rsaKey.ExportPkcs8PrivateKey();
                        var base64 = Convert.ToBase64String(pkcs8Bytes, Base64FormattingOptions.InsertLineBreaks);
                        
                        var builder = new StringBuilder();
                        builder.AppendLine("-----BEGIN PRIVATE KEY-----");
                        builder.AppendLine(base64);
                        builder.AppendLine("-----END PRIVATE KEY-----");
                        return builder.ToString();
                    }
                    catch
                    {
                        // Fallback to RSA-specific format
                        try
                        {
                            var rsaBytes = rsaKey.ExportRSAPrivateKey();
                            var base64 = Convert.ToBase64String(rsaBytes, Base64FormattingOptions.InsertLineBreaks);
                            
                            var builder = new StringBuilder();
                            builder.AppendLine("-----BEGIN RSA PRIVATE KEY-----");
                            builder.AppendLine(base64);
                            builder.AppendLine("-----END RSA PRIVATE KEY-----");
                            return builder.ToString();
                        }
                        catch
                        {
                            // Last resort: manual parameter export
                            return ExportRSAPrivateKeyManually(rsaKey);
                        }
                    }
                }

                Console.WriteLine("⚠ No supported private key algorithm found");
                return null;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error exporting private key to PEM: {ex.Message}");
                
                // Try alternative: export as PFX and suggest conversion
                try
                {
                    Console.WriteLine("💡 Attempting PFX export instead...");
                    var pfxBytes = cert.Export(X509ContentType.Pfx, "");
                    Console.WriteLine("✓ PFX export successful. You can convert this to PEM using OpenSSL:");
                    Console.WriteLine("   openssl pkcs12 -in cert.pfx -out cert.key -nodes -nocerts");
                    return "# PFX export successful - use OpenSSL to convert to PEM format";
                }
                catch (Exception pfxEx)
                {
                    Console.WriteLine($"✗ PFX export also failed: {pfxEx.Message}");
                    return null;
                }
            }
        }

        private static string ExportECDsaPrivateKeyToPem(System.Security.Cryptography.ECDsa ecdsaKey)
        {
            try
            {
                var pkcs8Bytes = ecdsaKey.ExportPkcs8PrivateKey();
                var base64 = Convert.ToBase64String(pkcs8Bytes, Base64FormattingOptions.InsertLineBreaks);
                
                var builder = new StringBuilder();
                builder.AppendLine("-----BEGIN PRIVATE KEY-----");
                builder.AppendLine(base64);
                builder.AppendLine("-----END PRIVATE KEY-----");
                return builder.ToString();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error exporting ECDSA private key: {ex.Message}");
                return null;
            }
        }

        private static string ExportRSAPrivateKeyManually(System.Security.Cryptography.RSA rsaKey)
        {
            try
            {
                var keyParams = rsaKey.ExportParameters(true);
                var builder = new StringBuilder();
                builder.AppendLine("-----BEGIN RSA PRIVATE KEY-----");

                // Export RSA private key parameters in base64 PEM format
                using (var ms = new MemoryStream())
                {
                    var writer = new BinaryWriter(ms);

                    // Write PKCS#1 RSA private key structure
                    writer.Write((byte)0x30); // SEQUENCE
                    using (var innerMs = new MemoryStream())
                    {
                        var innerWriter = new BinaryWriter(innerMs);
                        WriteIntegerBytes(innerWriter, new byte[] { 0x00 }); // Version
                        WriteIntegerBytes(innerWriter, keyParams.Modulus);
                        WriteIntegerBytes(innerWriter, keyParams.Exponent);
                        WriteIntegerBytes(innerWriter, keyParams.D);
                        WriteIntegerBytes(innerWriter, keyParams.P);
                        WriteIntegerBytes(innerWriter, keyParams.Q);
                        WriteIntegerBytes(innerWriter, keyParams.DP);
                        WriteIntegerBytes(innerWriter, keyParams.DQ);
                        WriteIntegerBytes(innerWriter, keyParams.InverseQ);

                        var length = (int)innerMs.Length;
                        WriteLength(writer, length);
                        writer.Write(innerMs.ToArray());
                    }

                    var base64 = Convert.ToBase64String(ms.ToArray(), Base64FormattingOptions.InsertLineBreaks);
                    builder.AppendLine(base64);
                }

                builder.AppendLine("-----END RSA PRIVATE KEY-----");
                return builder.ToString();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error in manual RSA export: {ex.Message}");
                return null;
            }
        }

        private static void WriteIntegerBytes(BinaryWriter writer, byte[] bytes)
        {
            writer.Write((byte)0x02); // INTEGER
            WriteLength(writer, bytes.Length);
            writer.Write(bytes);
        }

        private static void WriteLength(BinaryWriter writer, int length)
        {
            if (length < 0x80)
            {
                writer.Write((byte)length);
            }
            else if (length < 0x100)
            {
                writer.Write((byte)0x81);
                writer.Write((byte)length);
            }
            else
            {
                writer.Write((byte)0x82);
                writer.Write((byte)(length >> 8));
                writer.Write((byte)(length & 0xff));
            }
        }
    }
}