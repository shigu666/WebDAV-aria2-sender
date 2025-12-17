import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import java.io.File;
import java.io.PrintWriter;
import java.net.URLDecoder;
import java.net.URI;
import java.nio.charset.StandardCharsets;

public class WebDAVParser {

    public static void main(String[] args) {
        if (args.length != 3) {
            System.err.println("用法: java WebDAVParser <xml文件路径> <输出文件路径> <基础URL>");
            System.exit(1);
        }

        String xmlFilePath = args[0];
        String outputPath = args[1];
        String baseUrl = args[2];  // 必须以 / 结尾

        try {
            File xmlFile = new File(xmlFilePath);
            DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
            factory.setNamespaceAware(true);
            DocumentBuilder builder = factory.newDocumentBuilder();
            Document doc = builder.parse(xmlFile);
            doc.getDocumentElement().normalize();

            NodeList responseList = doc.getElementsByTagNameNS("DAV:", "response");

            URI baseUri = new URI(baseUrl);
            String scheme = baseUri.getScheme();
            String authority = baseUri.getAuthority();
            String basePrefix = scheme + "://" + authority;  // e.g., "https://webdav.example.com"

            PrintWriter writer = new PrintWriter(outputPath, StandardCharsets.UTF_8);

            int count = 0;

            for (int i = 0; i < responseList.getLength(); i++) {
                Element response = (Element) responseList.item(i);

                NodeList hrefList = response.getElementsByTagNameNS("DAV:", "href");
                if (hrefList.getLength() == 0) continue;

                String encodedHref = hrefList.item(0).getTextContent().trim();

                String decodedHref = URLDecoder.decode(encodedHref, StandardCharsets.UTF_8);

                String basePath = baseUri.getPath();
                if (decodedHref.equals(basePath) || decodedHref.equals(basePath.substring(0, basePath.length() - 1))) {
                    continue;
                }

                // 跳过目录
                boolean isCollection = false;
                NodeList propList = response.getElementsByTagNameNS("DAV:", "prop");
                if (propList.getLength() > 0) {
                    Element prop = (Element) propList.item(0);
                    NodeList resourcetypeList = prop.getElementsByTagNameNS("DAV:", "resourcetype");
                    if (resourcetypeList.getLength() > 0) {
                        Element resourcetype = (Element) resourcetypeList.item(0);
                        if (resourcetype.getElementsByTagNameNS("DAV:", "collection").getLength() > 0) {
                            isCollection = true;
                        }
                    }
                }
                if (isCollection) continue;

                String filename = decodedHref.substring(decodedHref.lastIndexOf('/') + 1);

                String fullUrl = basePrefix + encodedHref;

                // 使用 TAB 分隔，避免空格歧义
                writer.println(fullUrl + "\t" + filename);

                count++;
            }

            writer.close();

            System.out.println("成功生成 " + count + " 个文件条目到: " + outputPath);

        } catch (Exception e) {
            System.err.println("处理 XML 时发生错误:");
            e.printStackTrace();
            System.exit(1);
        }
    }
}