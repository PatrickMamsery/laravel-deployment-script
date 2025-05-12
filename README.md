# Laravel Deployment Script

This is a Bash script for deploying Laravel applications to a server. It automates the deployment process by asking for necessary information and configuring the server environment.

## Features

- Interactive deployment process with user prompts
- Automatic installation of required packages (PHP, Composer, etc.)
- Apache and Nginx server block/virtual host configuration
- MySQL database creation and user management (optional)
- Let's Encrypt SSL certificate setup (optional)
- Laravel `.env` configuration and key generation
- Composer dependency installation and migration support
- PHP version selection and extension management
- Colorized output for progress tracking and error reporting

## Requirements

- A server running Ubuntu 18.04 or later
- A Laravel application with a Git repository
- A user with sudo privileges on the server
- Apache or Nginx (optional configuration for both)

## Usage

1. Clone this repository:
   ```
   git clone https://github.com/PatrickMamsery/laravel-deployment-script.git
   ```
2. Change into the repository directory:
   ```
   cd laravel-deployment-script
   ```
3. Make the script executable:
   ```
   chmod +x deploy-laravel.sh
   ```
4. Run the script:
   ```
   ./deploy-laravel.sh
   ```
5. Follow the prompts to provide the required information.

## Configuration

The script is fully customizable. You can modify the deployment flow or adjust configurations like PHP version, server blocks, and more. Each section of the script is well-commented to make adjustments easy to implement.

## Customization Examples

- Apache Configuration: Edit the section for creating virtual hosts to adjust server configurations.
- SSL Setup: Modify the Let's Encrypt certificate generation process to suit your needs.

## Contributing

Contributions are always welcome! If you'd like to contribute, please fork the repository and submit a Pull Request. Bug reports, feature requests, and general improvements are all encouraged.

## Support

If you encounter any problems or have any questions, please open an issue on the GitHub repository.

<!-- ## License

This script is distributed under the XYZ License. See the [LICENSE](LICENSE) file for details. -->

## Acknowledgements

Thank you to all the contributors who have helped to improve this script.

If you find this script helpful, please consider giving it a star on GitHub!

This version emphasizes both **Apache** and **Nginx** support, as well as customization flexibility, while keeping a user-friendly tone. The script is designed to be easy to use and understand, even for beginners. It is a great starting point for deploying Laravel applications to a server.