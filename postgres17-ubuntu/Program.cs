using System.Runtime.InteropServices;
using System.Security.Cryptography.X509Certificates;
using System.Text;

class Program
{
    private const string DEFAULT_OUTPUT_DIR = @"C:\tmp\certs\";
    private const string CLIENT_CERT_SUBJECT = "redgatemonitor";
    private const string ROOT_CERT_SUBJECT = "127.0.0.1";

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
            string outputDir = args.Length > 0 ? args[0] : DEFAULT_OUTPUT_DIR;

            // Ensure output directory exists
            Directory.CreateDirectory(outputDir);

            var timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
            Console.WriteLine($"Exporting PostgreSQL certificates to: {outputDir}");
            Console.WriteLine($"Timestamp: {timestamp}");

            // Export client certificate and key from Personal store
            ExportClientCertificate(outputDir, timestamp);

            // Export root certificate from Trusted Root store
            ExportRootCertificate(outputDir, timestamp);

            Console.WriteLine("\nCertificate export completed!");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error: {ex.Message}");
        }
    }

    private static void ExportClientCertificate(string outputDir, string timestamp)
    {
        Console.WriteLine($"\n--- Exporting Client Certificate ({CLIENT_CERT_SUBJECT}) ---");
        
        using var store = new X509Store(StoreName.My, StoreLocation.CurrentUser);
        store.Open(OpenFlags.ReadOnly);

        var certificates = store.Certificates.Find(
            X509FindType.FindBySubjectName,
            CLIENT_CERT_SUBJECT,
            false);

        if (certificates.Count == 0)
        {
            Console.WriteLine($"No client certificates found for subject: {CLIENT_CERT_SUBJECT}");
            return;
        }

        foreach (var cert in certificates)
        {
            var certPath = Path.Combine(outputDir, $"redgatemonitor_{timestamp}.crt");
            var keyPath = Path.Combine(outputDir, $"redgatemonitor_{timestamp}.key");
            var pfxPath = Path.Combine(outputDir, $"redgatemonitor_{timestamp}.pfx");

            // Export public certificate
            var certPem = ExportCertificateToPem(cert);
            File.WriteAllText(certPath, certPem);
            Console.WriteLine($"✓ Client certificate exported to: {certPath}");

            // Export private key if available
            try
            {
                if (HasPrivateKey(cert))
                {
                    Console.WriteLine($"ℹ Certificate info: Subject={cert.Subject}, HasPrivateKey={cert.HasPrivateKey}");
                    Console.WriteLine($"ℹ Key algorithm: {cert.PublicKey.Oid.FriendlyName}");
                    Console.WriteLine($"ℹ Key size: {cert.PublicKey.Key.KeySize} bits");
                    
                    var privateKeyPem = ExportPrivateKeyToPem(cert);
                    if (!string.IsNullOrEmpty(privateKeyPem) && !privateKeyPem.StartsWith("#"))
                    {
                        File.WriteAllText(keyPath, privateKeyPem);
                        Console.WriteLine($"✓ Client private key exported to: {keyPath}");
                    }
                    else if (!string.IsNullOrEmpty(privateKeyPem))
                    {
                        Console.WriteLine($"ℹ {privateKeyPem}");
                    }

                    // Export as PFX (with empty password for compatibility)
                    var pfxBytes = cert.Export(X509ContentType.Pfx, "");
                    File.WriteAllBytes(pfxPath, pfxBytes);
                    Console.WriteLine($"✓ Client PFX exported to: {pfxPath}");
                    Console.WriteLine($"💡 You can convert PFX to PEM using:");
                    Console.WriteLine($"   openssl pkcs12 -in \"{pfxPath}\" -out redgatemonitor.key -nodes -nocerts");
                }
                else
                {
                    Console.WriteLine("⚠ No private key available for client certificate.");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"✗ Error exporting client private key: {ex.Message}");
            }
        }

        store.Close();
    }

    private static void ExportRootCertificate(string outputDir, string timestamp)
    {
        Console.WriteLine($"\n--- Exporting Root Certificate ({ROOT_CERT_SUBJECT}) ---");
        
        using var store = new X509Store(StoreName.Root, StoreLocation.CurrentUser);
        store.Open(OpenFlags.ReadOnly);

        var certificates = store.Certificates.Find(
            X509FindType.FindBySubjectName,
            ROOT_CERT_SUBJECT,
            false);

        if (certificates.Count == 0)
        {
            Console.WriteLine($"No root certificates found for subject: {ROOT_CERT_SUBJECT}");
            Console.WriteLine("Trying alternative search in Personal store...");
            
            // Fallback: search in Personal store
            using var personalStore = new X509Store(StoreName.My, StoreLocation.CurrentUser);
            personalStore.Open(OpenFlags.ReadOnly);
            certificates = personalStore.Certificates.Find(X509FindType.FindBySubjectName, ROOT_CERT_SUBJECT, false);
            personalStore.Close();
        }

        if (certificates.Count == 0)
        {
            Console.WriteLine($"No certificates found for subject: {ROOT_CERT_SUBJECT}");
            return;
        }

        foreach (var cert in certificates)
        {
            var certPath = Path.Combine(outputDir, $"server_{timestamp}.crt");

            // Export public certificate
            var certPem = ExportCertificateToPem(cert);
            File.WriteAllText(certPath, certPem);
            Console.WriteLine($"✓ Root certificate exported to: {certPath}");
        }

        store.Close();
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