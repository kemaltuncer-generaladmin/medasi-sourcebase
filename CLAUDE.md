# SourceBase Xcode MCP Setup

This project is configured to use the Xcode MCP (Model Context Protocol) server for iOS development automation.

## MCP Server: xcode-build

The Xcode MCP server enables Claude to:
- Run Xcode builds and tests
- Interact with the iOS simulator
- Automate UI testing workflows
- Query Xcode project structure

### Configuration

The MCP server is configured in `.xcodebuildmcp/config.yaml`:

```yaml
schemaVersion: 1
enabledWorkflows:
  - simulator
  - ui-automation
sessionDefaults:
  scheme: SourceBase
  projectPath: ./App/SourceBase.xcodeproj
  simulatorName: iPhone 17 Pro
```

### Project Details

- **Xcode Project**: `App/SourceBase.xcodeproj`
- **Scheme**: SourceBase
- **Default Simulator**: iPhone 17 Pro
- **Available Workflows**: simulator, ui-automation

### Usage

To use Xcode MCP tools in Claude Code:
1. The MCP server will be automatically discovered from the `.xcodebuildmcp` directory
2. Use `/run` skill to launch the app in the simulator
3. Use `/verify` skill to test changes
4. MCP tools will be available for build automation and testing

### Environment

- **Platform**: iOS/Swift (Xcode project)
- **Target Deployment**: iOS 17+
- **Build System**: Xcode 15+

### Related Files

- `.xcodebuildmcp/config.yaml` - MCP server configuration
- `App/SourceBase.xcodeproj` - Main Xcode project
- `App/gen_project.rb` - Project generation script
